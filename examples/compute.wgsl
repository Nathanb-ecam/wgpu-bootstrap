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

//fn getDistance(x1:f32 ,y1:f32 ,x2:f32 , y2:f32 )->f32{
  //  let dx = x2-x1;
    //let dy = y2-y1;
    //let result = sqrt(dx * dx + dy * dy);
    //return result;
//}

@group(0) @binding(0) var<storage, read_write> particlesData: array<Particle>;
@group(1) @binding(0) var<uniform> data: ComputationData;

//var<uniform> workgroup_size: i32 = data.workgroup_size as i32;





// il faut que le 64 soit gérer automatiquement 
@compute @workgroup_size(255, 1, 1) 
fn main(@builtin(global_invocation_id) param: vec3<u32>) {
    if (param.x >= u32(data.nb_instances)) {
          return;
    }

    var particle = particlesData[param.x];
    //particlesData[param.x].posx += data.delta_time * particle.vx;
    //particlesData[param.x].posy += data.delta_time * particle.vy;
    //particlesData[param.x].posz += data.delta_time * particle.vz;
    //particlesData[param.x].vy += data.delta_time * - 9.81;



    // collision     
    let particle_radius = data.particle_radius;


    // distance entre particule et sphere
    let x = (data.sx - particle.posx)*(data.sx - particle.posx); 
    let y = (data.sy - particle.posy)*(data.sy - particle.posy);
    let z = (data.sz - particle.posz)*(data.sz - particle.posz);
    let d = sqrt(x+y+z); 
    // distance utile comme comparaison pour determiner la collision

    // distance entre deux particules 


    // calculs des forces
    let inst_displ = 3.0;
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
    
    //float distance = getDistance(particle.posx,particle.posy,data.sx,data.sy); 

    
    // COLLISION
    if (  d < (data.sphere_r+particle_radius )){ 
        //particlesData[param.x].vy = -(particlesData[param.x].vy);
        particlesData[param.x].vy = 0.0;
        //particlesData[param.x].posx = ;
        //particlesData[param.x].posy = 0.0;
        //particlesData[param.x].posz = 0.0;
        //particlesData[param.x].vx += data.delta_time* 
        //particlesData[param.x].vy +=
        //particlesData[param.x].vz +=



        // mettre a jour Vitesse/Position en fonction des forces 
        //vx = vx + data.delta_time*(Rx/m)
        //vy = vy + data.delta_time*(Ry/m)
        //vz = vz + data.delta_time*(Rz/m)
        //posx = posx + data.delta_time*vx
        //posy = posy + data.delta_time*vy
        //posz = posz + data.delta_time*vz
    }

}
