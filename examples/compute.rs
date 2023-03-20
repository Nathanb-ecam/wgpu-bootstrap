use wgpu_bootstrap::{
    window::Window,
    frame::Frame,
    cgmath::{ self },
    application::Application,
    texture::create_texture_bind_group,
    context::Context,
    camera::Camera,
    default::{ Vertex, Particle },
    geometry::{icosphere, compute_line_list},
    computation::Computation,
    wgpu,
};
// pour la sphere de collision
const SPHERE_RADIUS:f32 = 25.0; // le facteur de réduction = rapport entre de taille de particule et taille de sphere de collision 
// particules du tissus
const PARTICLE_RADIUS:f32=1.0;
const NUM_INSTANCES_PER_ROW: u32 = 20;//10
const NUMBER_PARTICULES: u32 = NUM_INSTANCES_PER_ROW*NUM_INSTANCES_PER_ROW;//10
const INSTANCE_DISPLACEMENT: cgmath::Vector3<f32> = cgmath::Vector3::new(NUM_INSTANCES_PER_ROW as f32 * 1.5, 0.0, NUM_INSTANCES_PER_ROW as f32 * 1.5);//x:1.5, z:1.5



#[repr(C)]
#[derive(Copy, Clone, Debug, bytemuck::Pod, bytemuck::Zeroable)]
struct ComputeData {
    delta_time: f32,
    nb_instances: u32,
    particle_radius:f32,
    rotation_speed: f32,
    // pour la sphère,  positions et rayon
    sx:f32,
    sy:f32,
    sz:f32,
    sphere_r:f32,
    // simulation constants 
    stiffness:f32,
    mass:f32,
    damping_factor:f32,
}

struct MyApp {
    diffuse_bind_group: wgpu::BindGroup,
    camera_bind_group: wgpu::BindGroup,
    pipeline: wgpu::RenderPipeline,
    sphere_pipeline: wgpu::RenderPipeline,
    compute_pipeline: wgpu::ComputePipeline,
    vertex_buffer: wgpu::Buffer,
    sph_vertex_buffer: wgpu::Buffer,
    index_buffer: wgpu::Buffer,
    sph_index_buffer: wgpu::Buffer,
    particles: Vec<Particle>,
    particle_buffer: wgpu::Buffer,
    compute_instances_bind_group: wgpu::BindGroup,
    compute_data_buffer: wgpu::Buffer,
    compute_data_bind_group: wgpu::BindGroup,
    nb_indices: usize,
    sph_nb_indices:usize,
    workgroup_size:i32,
    workgroup_numbers:u32,
}

fn scale_sphere(vertices: Vec<Vertex>, factor: f32) -> Vec<Vertex>{
    //for vertex in vertices.iter_mut() {
    vertices.iter().map(|vertex| Vertex{
            position:[vertex.position[0]*factor,vertex.position[1]*factor,vertex.position[2]*factor],
            normal:[vertex.normal[0]*factor,vertex.normal[1]*factor,vertex.normal[2]*factor],// vertex.normal
            tangent:[vertex.tangent[0]*factor,vertex.tangent[1]*factor,vertex.tangent[2]*factor],//vertex.tangent
            tex_coords:vertex.tex_coords,
        }).collect()
}


fn get_workgroup_parameters(num_particles:u32,max_number:u32)->(i32,u32){
    let  workgroup_size:i32;
    let  num_workgroup:u32;
    if num_particles%max_number==0{ // pour éviter de recréer un workgroup vide si on a un multiple de 255,
        num_workgroup = num_particles/max_number;
    }
    else{
        num_workgroup = (num_particles/max_number)+1;
    }
    if num_workgroup ==1{
        workgroup_size = num_particles as i32;
    }
    else{
        workgroup_size = max_number as i32;
    }
        
    (workgroup_size,num_workgroup)
}

// had to modify the particle struct to have its neighbors 
fn compute_neighbor_springs(i:u32)->[u32;8] {// for the current particle
    let len :u32= NUMBER_PARTICULES;
    let side = (len as f32).sqrt() as u32;
    let mut neighbors:[u32;8] = [10000,10000,10000,10000,10000,10000,10000,10000];

    // Check west neighbor
    if i % side > 0 {
        let n_idx = i-1;
        neighbors[0]= n_idx;
    }
    // Check north-west neighbor (north index -1)
    // if i >= side {
    //     let n_idx = i-side;
    //     neighbors[1]= n_idx -1;
    // }
    // Check north neighbor
    if i >= side {
        let n_idx = i-side;
        neighbors[2]= n_idx;
    }
    // Check north-east neighbor (north index +1)
    // if i >= side {
    //     let n_idx = i-side;
    //     neighbors[3]= n_idx+1;
    // }
    // Check east neighbor
    if i % side < side-1 {
        let n_idx = i+1;
        neighbors[4]= n_idx;
    }
    // Check south-east neighbor
    // if i < len-side {
    //     let n_idx = i+side;
    //     neighbors[5]= n_idx+1;
    // }
    // Check south neighbor
    if i < len-side {
        let n_idx = i+side;
        neighbors[6]= n_idx;
    }
    // Check south-west neighbor
    // if i < len-side {
    //     let n_idx = i+side;
    //     neighbors[7]= n_idx-1;
    // }
    neighbors
}

impl MyApp {
    fn new(context: &Context) -> Self {
        let texture = context.create_srgb_texture("happy-tree.png", include_bytes!("happy-tree.png"));
    
        let diffuse_bind_group = create_texture_bind_group(context, &texture);
    
        let camera = Camera {
            eye: (0.0, 25.0, 75.0).into(),// permet de gérer le zoom 
            target: (0.0, 30.0, 0.0).into(),
            up: cgmath::Vector3::unit_y(),
            aspect: context.get_aspect_ratio(),
            fovy: 120.0,//45
            znear: 0.1,
            zfar: 100.0,
        };

        let (_camera_buffer, camera_bind_group) = camera.create_camera_bind_group(context);
    
        let pipeline = context.create_render_pipeline(
            "Render Pipeline",
            include_str!("shader_instances.wgsl"),
            &[Vertex::desc(), Particle::desc()],
            &[
                &context.texture_bind_group_layout,
                &context.camera_bind_group_layout,
            ],
            wgpu::PrimitiveTopology::TriangleList
        );


        // PARTICLES 
        // on calule le nombre de bindgroups adapté et workgroup size
        let (workgroup_size,workgroup_numbers) = get_workgroup_parameters(NUMBER_PARTICULES,255);
        // on crée les particules à partir d'icosphere
        let (mut vertices, indices) = icosphere(4);
        vertices = scale_sphere(vertices, PARTICLE_RADIUS);
        //let radius_vertices = get_particule_radius(&vertices);
        //print!("{:?}",vertices);
                      
    
        let vertex_buffer = context.create_buffer(vertices.as_slice(), wgpu::BufferUsages::VERTEX);
        let index_buffer = context.create_buffer(indices.as_slice(), wgpu::BufferUsages::INDEX);

        let particles = (0..NUM_INSTANCES_PER_ROW*NUM_INSTANCES_PER_ROW).map(|index| { // il faut remplacer les instances ppar des particules
            // les instances sont des matrices qui transforment les sphères pour les déplacer translation et rotataion
            // et modifier le shader_instance.wgsl ligne 11 : adapter le struct pour 
            let x = index % NUM_INSTANCES_PER_ROW;
            let z = index / NUM_INSTANCES_PER_ROW;
            let position = cgmath::Vector3 { x: x as f32 * 3.0, y: 35.0, z: z as f32 * 3.0 } - INSTANCE_DISPLACEMENT;//x :3.0 ,y :0, z :3.0
            let neighbors = compute_neighbor_springs(index);
            // println!("{:?}{}{:?}",position,index,neighbors);
            
            Particle {
                position: position.into(), velocity:[0.0,0.0,0.0],neighbors:neighbors,
            }
            
            

        }).collect::<Vec<_>>();



        
        
        // il ne faut pas convertir les particles pour pouvoir les bufferiser
        let particle_buffer = context.create_buffer(particles.as_slice(), wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::STORAGE);
        
        // This compute pipeline will use 2 bind group as declared in its source
        let compute_pipeline = context.create_compute_pipeline("Compute Pipeline", include_str!("compute.wgsl"));

        // This is the first bind group for the compute pipeline
        let compute_instances_bind_group = context.create_bind_group(
            "Compute Bind Group",
            &compute_pipeline.get_bind_group_layout(0),
            &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: particle_buffer.as_entire_binding(),
                }
            ]
        );

        // This is the second bind group for the compute pipeline. The buffer will be updated each
        // frame
        let compute_data = ComputeData {
            delta_time: 0.016,
            nb_instances: NUM_INSTANCES_PER_ROW*NUM_INSTANCES_PER_ROW,//100
            particle_radius:PARTICLE_RADIUS,
            rotation_speed: 1.0,
            sx:0.0,
            sy:0.0,
            sz:0.0,
            sphere_r:SPHERE_RADIUS,//1
            stiffness:1.0,
            mass:10.0,
            damping_factor:1.0,

        };
        let compute_data_buffer = context.create_buffer(&[compute_data], wgpu::BufferUsages::UNIFORM);
        let compute_data_bind_group = context.create_bind_group(
            "Compute Data", 
            &compute_pipeline.get_bind_group_layout(1), 
            &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: compute_data_buffer.as_entire_binding(),
                }
            ]
        );


        //SPHERE OF COLLISION 

        let sphere_pipeline = context.create_render_pipeline(
            "Render Pipeline",
            include_str!("blue.wgsl"),
            &[Vertex::desc()],
            &[
                &context.camera_bind_group_layout,
            ],
            wgpu::PrimitiveTopology::LineList
        );

        let (mut sph_vertices, sph_indices) = icosphere(4);

        sph_vertices= scale_sphere(sph_vertices, SPHERE_RADIUS); 

   
        let sph_indices = compute_line_list(sph_indices);

        let sph_vertex_buffer = context.create_buffer(sph_vertices.as_slice(), wgpu::BufferUsages::VERTEX);
        let sph_index_buffer = context.create_buffer(sph_indices.as_slice(), wgpu::BufferUsages::INDEX);



        Self {
            diffuse_bind_group,
            camera_bind_group,
            pipeline,
            sphere_pipeline,
            compute_pipeline,
            vertex_buffer,
            index_buffer,
            sph_vertex_buffer,
            sph_index_buffer,
            particles,
            particle_buffer,
            compute_instances_bind_group,
            compute_data_buffer,
            compute_data_bind_group,
            nb_indices: indices.len(),
            sph_nb_indices: sph_indices.len(),
            workgroup_size,
            workgroup_numbers,

        }
    }
}

impl Application for MyApp {
    fn render(&self, context: &Context) -> Result<(), wgpu::SurfaceError> {
        let mut frame = Frame::new(context)?;

        {
            // pour les particules du tissus
            let mut render_pass = frame.begin_render_pass(wgpu::Color {r: 0.1, g: 0.2, b: 0.3, a: 1.0});

            render_pass.set_pipeline(&self.pipeline);
            render_pass.set_bind_group(0, &self.diffuse_bind_group, &[]);
            render_pass.set_bind_group(1, &self.camera_bind_group, &[]);
            render_pass.set_vertex_buffer(0, self.vertex_buffer.slice(..));
            render_pass.set_vertex_buffer(1, self.particle_buffer.slice(..));
            render_pass.set_index_buffer(self.index_buffer.slice(..), wgpu::IndexFormat::Uint16);
            render_pass.draw_indexed(0..(self.nb_indices as u32), 0, 0..self.particles.len() as _);
            

            // pour la sphere
            render_pass.set_pipeline(&self.sphere_pipeline);
            render_pass.set_bind_group(0, &self.camera_bind_group, &[]);
            render_pass.set_vertex_buffer(0, self.sph_vertex_buffer.slice(..));
            render_pass.set_index_buffer(self.sph_index_buffer.slice(..), wgpu::IndexFormat::Uint16);
            render_pass.draw_indexed(0..(self.sph_nb_indices as u32), 0, 0..1);

        }

        frame.present();

        Ok(())
    }

    fn update(&mut self, context: &Context, delta_time: f32) {
        // Update the Buffer that contains the delta_time
        let compute_data = ComputeData {
            delta_time,
            nb_instances: NUM_INSTANCES_PER_ROW*NUM_INSTANCES_PER_ROW,
            particle_radius:PARTICLE_RADIUS,
            rotation_speed: 2.0,
            sx:0.0,
            sy:0.0,
            sz:0.0,
            sphere_r:SPHERE_RADIUS,
            stiffness:100.0,
            mass:1.0,//1
            damping_factor:0.1,

        }; 

        context.update_buffer(&self.compute_data_buffer, &[compute_data]);
        

        let mut computation = Computation::new(context);

        {
            let mut compute_pass = computation.begin_compute_pass();

            compute_pass.set_pipeline(&self.compute_pipeline);
            compute_pass.set_bind_group(0, &self.compute_instances_bind_group, &[]);
            compute_pass.set_bind_group(1, &self.compute_data_bind_group, &[]);
            compute_pass.set_bind_group(1, &self.compute_data_bind_group, &[]);
            compute_pass.dispatch_workgroups(self.workgroup_numbers, 1, 1);//parametre x permet de créer x le workgroup dont la size est définie dans le wgsl workgroupsize(64) donc x fois 64 thread
        }

        computation.submit();
    }
}

fn main() {
    let window = Window::new();

    let context = window.get_context();

    let my_app = MyApp::new(context);

    window.run(my_app);
}
