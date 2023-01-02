use wgpu_bootstrap::{
    window::Window,
    frame::Frame,
    cgmath,
    application::Application,
    context::Context,
    camera::Camera,
    default::Vertex,
    geometry::{icosphere, compute_line_list},
    wgpu,
};

struct MyApp {
    camera_bind_group: wgpu::BindGroup,
    pipeline: wgpu::RenderPipeline,
    vertex_buffer: wgpu::Buffer,
    index_buffer: wgpu::Buffer,
    nb_indices: usize,
}

fn scale_sphere(vertices: Vec<Vertex>, factor: f32) -> Vec<Vertex>{
    //for vertex in vertices.iter_mut() {
    vertices.iter().map(|vertex| Vertex{
            position:[vertex.position[0]*factor,vertex.position[1]*factor,vertex.position[2]*factor],
            normal:vertex.normal,
            tangent:vertex.tangent,
            tex_coords:vertex.tex_coords,
        }).collect()
}

impl MyApp {
    fn new(context: &Context) -> Self {
        let camera = Camera {
            eye: (0.0, 2.0, 4.0).into(),
            target: (0.0, 0.0, 0.0).into(),
            up: cgmath::Vector3::unit_y(),
            aspect: context.get_aspect_ratio(),
            fovy: 45.0,
            znear: 0.1,
            zfar: 100.0,
        };

        let (_camera_buffer, camera_bind_group) = camera.create_camera_bind_group(context);
    
        let pipeline = context.create_render_pipeline(
            "Render Pipeline",
            include_str!("blue.wgsl"),
            &[Vertex::desc()],
            &[
                &context.camera_bind_group_layout,
            ],
            wgpu::PrimitiveTopology::LineList
        );

        let (mut vertices, indices) = icosphere(4);
   
        vertices = scale_sphere(vertices, 0.5);
        
        let indices = compute_line_list(indices);

        let vertex_buffer = context.create_buffer(vertices.as_slice(), wgpu::BufferUsages::VERTEX);
        let index_buffer = context.create_buffer(indices.as_slice(), wgpu::BufferUsages::INDEX);

        Self {
            camera_bind_group,
            pipeline,
            vertex_buffer,
            index_buffer,
            nb_indices: indices.len(),
        }
    }
}

impl Application for MyApp {
    fn render(&self, context: &Context) -> Result<(), wgpu::SurfaceError> {
        let mut frame = Frame::new(context)?;

        {
            let mut render_pass = frame.begin_render_pass(wgpu::Color {r: 0.1, g: 0.2, b: 0.3, a: 1.0});

            render_pass.set_pipeline(&self.pipeline);
            render_pass.set_bind_group(0, &self.camera_bind_group, &[]);
            render_pass.set_vertex_buffer(0, self.vertex_buffer.slice(..));
            render_pass.set_index_buffer(self.index_buffer.slice(..), wgpu::IndexFormat::Uint16);
            render_pass.draw_indexed(0..(self.nb_indices as u32), 0, 0..1);
        }

        frame.present();

        Ok(())
    }
}

fn main() {
    let window = Window::new();

    let context = window.get_context();

    let my_app = MyApp::new(context);

    window.run(my_app);
}
