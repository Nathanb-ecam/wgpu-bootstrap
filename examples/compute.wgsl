struct Particle {
    posx:f32,posy:f32,posz:f32,
    vx:f32,vy:f32,vz:f32,
    //index of the neighbors (left,up,right,down)
    n_west:u32,n_north_west:u32,n_north:u32,n_north_east:u32,
    n_east:u32,n_south_east:u32,n_south:u32,n_south_west:u32,

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

// REMARQUES :  travailler avec des vec3 -> fonctions préconçues : length, normalize, reflect,...

fn getDistanceToSphere(x:f32 ,y:f32 ,z:f32)->f32{// MIEUX prendre un vec en parametre plutot que les trois coord
    let x = (x-data.sx)*(x-data.sx); 
    let y = (y-data.sy)*(y-data.sy);
    let z = (z-data.sz)*(z-data.sz); 
    let d = sqrt(x+y+z); 
    return d;
}
fn getDistanceBetweenParticles(part1:vec3<f32> ,part2:vec3<f32>)->f32{// MIEUX prendre un vec en parametre plutot que les trois coord
    let x = (part1.x-part2.x)*(part1.x-part2.x); 
    let y = (part1.y-part2.y)*(part1.y-part2.y);
    let z = (part1.z-part2.z)*(part1.z-part2.z); 
    let d = sqrt(x+y+z); 
    return d;
}

// fn getDisplacement(i:u32,n_idx:u32)-> f32{ // the distance between two particles
//     var dl = getDistanceBetweenParticles(particlesData[i],particlesData[n_idx]);
//     // var dx = particlesData[n_idx].posx - particlesData[i].posx;
//     // var dy = particlesData[n_idx].posy - particlesData[i].posy;
//     // var dz = particlesData[n_idx].posz - particlesData[i].posz;
//     if (dl == 3.0 || dl == -3.0){
//         dl = 0.0;
//     }
//     else{
//         dl -= 3.0;
//     }

//     return dl;
// }

// fn calculate_force(i:u32,n_idx:u32)->f32{
//     // REMARQUES : force ne dépend pas de chaque composante dx, dy, dz mais de l'allongement général
//     // let deltaL = getDisplacement(i,n_idx);
//     let part = vec3(particlesData[i].posx,particlesData[i].posy,particlesData[i].posz);
//     let neigh = vec3(particlesData[n_idx].posx,particlesData[n_idx].posy,particlesData[n_idx].posz);
//     var deltaL = length(part - neigh);
//     let dir = vec3((part-neigh)/deltaL);
//     deltaL -= 3.0;
//     let scalar_f = data.stiffness*deltaL;
//     let force:vec3<f32> =  dir*scalar_f;
//     // force.fx = data.stiffness * deltaL.dx; //= Fx
//     // force.fy = (-9.81 *data.mass) + (data.stiffness * deltaL.dy) ; //+ Fy
//     // force.fz = data.stiffness*deltaL.dz;
//     return force;
// }




fn process_neighbor(n_index: u32, c_index: u32) -> vec3<f32> {
    let neighbor = particlesData[n_index];
    let current = particlesData[c_index];
    let part = vec3(current.posx,current.posy,current.posz);
    let neigh = vec3(neighbor.posx,neighbor.posy,neighbor.posz);
    let dl = length(neigh - part);
    let scalar_f = data.stiffness * (dl- 3.0);
    let dir = (neigh-part)/dl;
    let force = scalar_f * dir;
    return force;
}

@compute @workgroup_size(255, 1, 1) 
fn main(@builtin(global_invocation_id) param: vec3<u32>) {
    if (param.x >= u32(data.nb_instances)) {
          return;
    }
    var current = particlesData[param.x];    // references the current particle
    let current_index = param.x;
    let particle_radius = data.particle_radius;


    let neighbors_indexes:array<u32,4> = array<u32,4>(particlesData[param.x].n_west,particlesData[param.x].n_north,particlesData[param.x].n_east,particlesData[param.x].n_south);
    

    let max_u32:u32 = 4294967295u;

    // REMARQUES :itérer sur les particules voisines
    var resultant = vec3<f32>(0.0,0.0,0.0);
    //for(var i = 0u;i<4u;i++){
        // i+=0u;
        //let neighbor_index = neighbors_indexes[i];
        //let neighbor = particlesData[neighbor_index];
        //let part = vec3(current.posx,current.posy,current.posz);
        //let neigh = vec3(neighbor.posx,neighbor.posy,neighbor.posz);
        //let dl = length(part - neigh);
        //let scalar_f = data.stiffness * (dl- 3.0);
        //let dir = (part-neigh)/dl;
        //let force = scalar_f * dir;
    //}
    if (particlesData[param.x].n_west != 10000u){
        resultant += process_neighbor(particlesData[param.x].n_west, current_index);
    }
    if (particlesData[param.x].n_north != 10000u){
        resultant += process_neighbor(particlesData[param.x].n_north, current_index);
    }
    if (particlesData[param.x].n_east != 10000u){
        resultant += process_neighbor(particlesData[param.x].n_east, current_index);
    }
    if (particlesData[param.x].n_south != 10000u){
        resultant += process_neighbor(particlesData[param.x].n_south, current_index);
    }
    resultant += vec3(0.0,-9.81,0.0);


    // let rx = -data.stiffness * 0.0; //= Fx
    // let ry = -9.81 *data.mass ; //+ Fy
    // let rz = -data.stiffness*0.0;


    // on met a jour les vitesses et positions des particules 
    particlesData[param.x].vx = particlesData[param.x].vx + data.delta_time*(resultant.x/data.mass);
    particlesData[param.x].vy = particlesData[param.x].vy + data.delta_time*(resultant.y/data.mass);
    //particlesData[0].vy = particlesData[0].vy + data.delta_time*(9.81);
    particlesData[param.x].vz = particlesData[param.x].vz + data.delta_time*(resultant.z/data.mass);

    particlesData[param.x].posx += data.delta_time * current.vx;
    particlesData[param.x].posy += data.delta_time * current.vy;
    particlesData[param.x].posz += data.delta_time * current.vz;
    


    // distance entre particule et sphere
    let d = getDistanceToSphere(current.posx,current.posy,current.posz); 
    let delt = length(vec3(particlesData[param.x].vx,particlesData[param.x].vy,particlesData[param.x].vz));



    // COLLISION
    var sphere_center = vec3<f32>(data.sx,data.sy,data.sz);
    var posn = vec3<f32>(particlesData[param.x].posx,particlesData[param.x].posy,particlesData[param.x].posz);
    var velocity = vec3<f32>(particlesData[param.x].vx,particlesData[param.x].vy,particlesData[param.x].vz);
    var d_origin = posn-sphere_center;
    if (  d < (data.sphere_r+particle_radius)){ 
        var dir = normalize(d_origin);
        // on applique cette normale sur le vecteur vitesse
        velocity = reflect(velocity,dir);
        posn = sphere_center + dir * (data.sphere_r*1.03);//1%

        particlesData[param.x].posx = posn.x;
        particlesData[param.x].posy = posn.y;
        particlesData[param.x].posz = posn.z;

        particlesData[param.x].vx = velocity.x*0.9;
        particlesData[param.x].vy = velocity.y*0.9;
        particlesData[param.x].vz = velocity.z*0.9;

    }

}
