struct Particle {
    posx:f32,posy:f32,posz:f32,
    vx:f32,vy:f32,vz:f32,

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



@group(0) @binding(0) var<storage, read_write> particlesData: array<Particle>;
@group(1) @binding(0) var<uniform> data: ComputationData;



fn getDistance(x:f32 ,y:f32 ,z:f32)->f32{// MIEUX prendre un vec en parametre plutot que les trois coord
    let x = (x-data.sx)*(x-data.sx); 
    let y = (y-data.sy)*(y-data.sy);
    let z = (z-data.sz)*(z-data.sz); 
    let d = sqrt(x+y+z); 
    return d;
}




// il faut que le 64 soit gérer automatiquement 
@compute @workgroup_size(255, 1, 1) 
fn main(@builtin(global_invocation_id) param: vec3<u32>) {
    if (param.x >= u32(data.nb_instances)) {
          return;
    }

    var particle = particlesData[param.x];




    // collision     
    let particle_radius = data.particle_radius;


    // distance entre particule et sphere
    let d = getDistance(particle.posx,particle.posy,particle.posz); 
    // distance utile comme comparaison pour determiner la collision

    // distance entre deux particules 


    // calculs des forces
    //F = -k*delta_l = -data.stiffness*delta_l
    let Rx = -data.stiffness * 0.0; //= Fx
    let Ry = -9.81 *data.mass ; //+ Fy
    let Rz = -data.stiffness*0.0;

    particlesData[param.x].vx = particlesData[param.x].vx + data.delta_time*(Rx/data.mass);
    particlesData[param.x].vy = particlesData[param.x].vy + data.delta_time*(Ry/data.mass);
    //particlesData[0].vy = particlesData[0].vy + data.delta_time*(9.81);
    particlesData[param.x].vz = particlesData[param.x].vz + data.delta_time*(Rz/data.mass);

    particlesData[param.x].posx += data.delta_time * particle.vx;
    particlesData[param.x].posy += data.delta_time * particle.vy;
    particlesData[param.x].posz += data.delta_time * particle.vz;
    


    
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
