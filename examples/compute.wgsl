struct Particle {
    posx:f32,posy:f32,posz:f32,
    vx:f32,vy:f32,vz:f32,
    n_west:u32,
    n_north:u32,
    n_east:u32,
    n_south:u32,

}

struct ComputationData {
    delta_time: f32,
    nb_instances: u32,
    particle_radius:f32,
    rotation_speed: f32,
    sx:f32,sy:f32,sz:f32,
    sphere_r:f32,
    stiffness:f32,
    mass:f32,
    damping_factor:f32,
}

struct DeltaL {
    dx:f32,
    dy:f32,
    dz:f32,
}
struct Force {
    fx:f32,
    fy:f32,
    fz:f32,
}
struct Neighbors {
    west:u32,
    north:u32,
    east:u32,
    south:u32,
}

@group(0) @binding(0) var<storage, read_write> particlesData: array<Particle>;
@group(1) @binding(0) var<uniform> data: ComputationData;



fn getDistanceToSphere(x:f32 ,y:f32 ,z:f32)->f32{// MIEUX prendre un vec en parametre plutot que les trois coord
    let x = (x-data.sx)*(x-data.sx); 
    let y = (y-data.sy)*(y-data.sy);
    let z = (z-data.sz)*(z-data.sz); 
    let d = sqrt(x+y+z); 
    return d;
}

fn getDistance(i:u32,n_idx:u32)-> DeltaL{ // the distance between two particles
    var res : DeltaL; 
    var dx = particlesData[i].posx - particlesData[n_idx].posx;
    var dy = particlesData[i].posy - particlesData[n_idx].posy;
    var dz = particlesData[i].posz - particlesData[n_idx].posz;
    if dx == 3.0{
        res.dx = 0.0;
    }
    if dy == 3.0{
        res.dy = 0.0;
    }
    if dz == 3.0{
        res.dz = 0.0;
    }
    return res;
}

fn calculate_force(i:u32,n_idx:u32)->Force{
    let deltaL = getDistance(i,n_idx);
    var force : Force;
    force.fx = -data.stiffness * deltaL.dx; //= Fx
    force.fy = (-9.81 *data.mass) + (-data.stiffness * deltaL.dy) ; //+ Fy
    force.fz = -data.stiffness*deltaL.dz;
    return force;
}






@compute @workgroup_size(255, 1, 1) 
fn main(@builtin(global_invocation_id) param: vec3<u32>) {
    if (param.x >= u32(data.nb_instances)) {
          return;
    }
    var particle = particlesData[param.x];    
    let particle_radius = data.particle_radius;
    let i = param.x;
    //let arr = vec4(particle.n_west,particle.n_north,particle.n_east,particle.n_south);


    //MARCHE
    let rx = -data.stiffness * 0.0; //= Fx
    let ry = -9.81 *data.mass ; //+ Fy
    let rz = -data.stiffness*0.0;

    // var rx = 0.0;
    // var ry = 0.0;
    // var rz = 0.0;
    // setting current neighbors
    var neighbors:Neighbors;
    neighbors.west = particle.n_west;
    neighbors.north = particle.n_north;
    neighbors.east = particle.n_east;
    neighbors.south = particle.n_south;


    // //west
    // if (neighbors.west != u32.max){
    //     let force = calculate_force(i,neighbors[0]);
    //     rx += force.fx;
    //     ry += force.fy;
    //     rz += force.fz;
    // } 
    // //north
    // if (neighbors.north != u32.max){
    //     let force = calculate_force(i,neighbors[1]);
    //     rx += force.fx;
    //     ry += force.fy;
    //     rz += force.fz;
    // } 
    // //east
    // if (neighbors.east != u32.max){
    //     let force = calculate_force(i,neighbors[2]);
    //     rx += force.fx;
    //     ry += force.fy;
    //     rz += force.fz;
    // } 
    // //south
    // if (neighbors.south != u32.max){
    //     let force = calculate_force(i,neighbors[3]);
    //     rx += force.fx;
    //     ry += force.fy;
    //     rz += force.fz;
    // } 





    // on met a jour les vitesses et positions des particules 
    particlesData[param.x].vx = particlesData[param.x].vx + data.delta_time*(rx/data.mass);
    particlesData[param.x].vy = particlesData[param.x].vy + data.delta_time*(ry/data.mass);
    //particlesData[0].vy = particlesData[0].vy + data.delta_time*(9.81);
    particlesData[param.x].vz = particlesData[param.x].vz + data.delta_time*(rz/data.mass);

    particlesData[param.x].posx += data.delta_time * particle.vx;
    particlesData[param.x].posy += data.delta_time * particle.vy;
    particlesData[param.x].posz += data.delta_time * particle.vz;
    


    // distance entre particule et sphere
    let d = getDistanceToSphere(particle.posx,particle.posy,particle.posz); 
    // COLLISION
    if (  d < (data.sphere_r+particle_radius)){ 

        particlesData[param.x].vy = 0.0;

        // remettre le particule hors de la sphere
        let vec_part = vec3(particlesData[param.x].posx,particlesData[param.x].posy,particlesData[param.x].posz);
        let vec_norm = vec_part*(d/length(vec_part)); //pour obtenir un vecteur d'une norme d qui a la meme direction que vec_part
        let result = vec_part - vec_norm;
        particlesData[param.x].posx -= result.x;
        particlesData[param.x].posy -= result.y;
        particlesData[param.x].posz -= result.z;


    }

}
