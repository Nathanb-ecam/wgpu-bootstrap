struct Particle {
    posx:f32,posy:f32,posz:f32,
    vx:f32,vy:f32,vz:f32,
    n_west:u32,//index of the west neighbor
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

fn getDisplacement(i:u32,n_idx:u32)-> DeltaL{ // the distance between two particles
    var res : DeltaL; 
    //dl
    //var dl = getDistanceBetweenParticles(particlesData[param.x],particlesData[param.x])
    var dx = particlesData[n_idx].posx - particlesData[i].posx;
    var dy = particlesData[n_idx].posy - particlesData[i].posy;
    var dz = particlesData[n_idx].posz - particlesData[i].posz;
    if (dx == 3.0 || dx == -3.0){
        dx = 0.0;
    }
    else{
        dx -= 3.0;
    }
    if (dz == 3.0 || dz == -3.0){
        dz = 0.0;
    }
    else{
        dz -= 3.0;
    }
    
    res.dx =dx;
    res.dy =dy;
    res.dz =dz;
    return res;
}

fn calculate_force(i:u32,n_idx:u32)->Force{
    // REMARQUES : force ne dépend pas de chaque composante dx, dy, dz mais de l'allongement général
    let deltaL = getDisplacement(i,n_idx);
    var force : Force;
    force.fx = -data.stiffness * deltaL.dx; //= Fx
    force.fy = (-9.81 *data.mass) + (data.stiffness * deltaL.dy) ; //+ Fy
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



    var rx = 0.0;
    var ry = 0.0;
    var rz = 0.0;
    // setting current neighbors

    let neighbors = vec4(particlesData[param.x].n_west,particlesData[param.x].n_north,particlesData[param.x].n_east,particlesData[param.x].n_south);
    

    let v:u32 = 1000u;

    // REMARQUES :itérer sur les particules voisines
    // for(var i = 0)

    if (particle.n_west != v){
        let force = calculate_force(i,particle.n_west);
        rx += force.fx;
        ry += force.fy;
        rz += force.fz;
    } 
    //north
    if (particle.n_north != v){
        let force = calculate_force(i,particle.n_north);
        rx += force.fx;
        ry += force.fy;
        rz += force.fz;
    } 
    //east
    if (particle.n_east != v){
        let force = calculate_force(i,particle.n_east);
        rx += force.fx;
        ry += force.fy;
        rz += force.fz;
    } 
    //south
    if (particle.n_south != v){
        let force = calculate_force(i,particle.n_south);
        rx += force.fx;
        ry += force.fy;
        rz += force.fz;
    } 


    // let rx = -data.stiffness * 0.0; //= Fx
    // let ry = -9.81 *data.mass ; //+ Fy
    // let rz = -data.stiffness*0.0;


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
    let delt = length(vec3(particlesData[param.x].vx,particlesData[param.x].vy,particlesData[param.x].vz));



    // COLLISION
    var sphere_center = vec3<f32>(data.sx,data.sy,data.sz);
    var posn = vec3<f32>(particlesData[param.x].posx,particlesData[param.x].posy,particlesData[param.x].posz);
    var velocity = vec3<f32>(particlesData[param.x].vx,particlesData[param.x].vy,particlesData[param.x].vz);
    var d_origin = posn-sphere_center;
    if (  d < (data.sphere_r+particle_radius)){ 

        // particlesData[param.x].vx = 0.0;
        // particlesData[param.x].vy = 0.0;
        // particlesData[param.x].vz = 0.0;

        // remettre le particule hors de la sphere
        // let vec_part = vec3(particlesData[param.x].posx,particlesData[param.x].posy,particlesData[param.x].posz);
        // let vec_norm = vec_part*(d/length(vec_part)); //pour obtenir un vecteur d'une norme d qui a la meme direction que vec_part
        // let result = vec_part - vec_norm;
        // particlesData[param.x].posx -= result.x;
        // particlesData[param.x].posy -= result.y;
        // particlesData[param.x].posz -= result.z;

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
