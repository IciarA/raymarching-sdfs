#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;
uniform bool u_Anim;
uniform float u_Red;
uniform float u_Green;
uniform float u_Blue;

in vec2 fs_Pos;
out vec4 out_Col;

// Noise Functions
float rand(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Perlin noise 
vec2 hash( vec2 x )
{
    const vec2 k = vec2( 0.3183099, 0.3678794 );
    x = x*k + k.yx;
    return -1.0 + 2.0*fract( 16.0 * k*fract( x.x*x.y*(x.x+x.y)) );
}

float noised( vec2 p )
{
  vec2 i = floor( p );
  vec2 f = fract( p );

  vec2 u = f*f*f*(f*(f*6.0-15.0)+10.0);
  vec2 du = 30.0*f*f*(f*(f-2.0)+1.0);

  vec2 ga = hash( i + vec2(0.0,0.0) );
  vec2 gb = hash( i + vec2(1.0,0.0) );
  vec2 gc = hash( i + vec2(0.0,1.0) );
  vec2 gd = hash( i + vec2(1.0,1.0) );

  float va = dot( ga, f - vec2(0.0,0.0) );
  float vb = dot( gb, f - vec2(1.0,0.0) );
  float vc = dot( gc, f - vec2(0.0,1.0) );
  float vd = dot( gd, f - vec2(1.0,1.0) );

  return va + u.x*(vb-va) + u.y*(vc-va) + u.x*u.y*(va-vb-vc+vd);
}




// SDFs

float sdSphere( vec3 p, float s )
{
  return length(p) - s; 
}

float sdVerticalCapsule( vec3 p, float h, float r )
{
  p.y -= clamp( p.y, 0.0, h );
  return length( p ) - r;
}


float sdCapsule( vec3 p, vec3 a, vec3 b, float r )
{
  vec3 pa = p - a, ba = b - a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
  return length( pa - ba*h ) - r;
}

float sdRoundCone( vec3 p, float r1, float r2, float h )
{
  vec2 q = vec2( length(p.xz), p.y );
    
  float b = (r1-r2)/h;
  float a = sqrt(1.0-b*b);
  float k = dot(q,vec2(-b,a));
    
  if( k < 0.0 ) return length(q) - r1;
  if( k > a*h ) return length(q-vec2(0.0,h)) - r2;
        
  return dot(q, vec2(a,b) ) - r1;
}


float sdEllipsoid( vec3 p, vec3 r )
{
  float k0 = length(p/r);
  float k1 = length(p/(r*r));
  return k0*(k0-1.0)/k1;
}

float sdCappedCylinder( vec3 p, vec2 h )
{
  vec2 d = abs(vec2(length(p.xz),p.y)) - h;
  return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}


float sdBox( vec3 p, vec3 b )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}


// Smooth Operations
float opSmoothSubtraction( float d1, float d2, float k ) {
  float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
  return mix( d2, -d1, h ) + k*h*(1.0-h); 
}

float opSmoothIntersection( float d1, float d2, float k ) {
  float h = clamp( 0.5 - 0.5*(d2-d1)/k, 0.0, 1.0 );
  return mix( d2, d1, h ) + k*h*(1.0-h);
}

// polynomial smooth min (k = 0.1);
float sminCubic( float a, float b, float k )
{
    float h = max( k-abs(a-b), 0.0 )/k;
    return min( a, b ) - h*h*h*k*(1.0/6.0);
}


// Other Operations

float rounding(float d, float h )
{
    return d - h;
}

vec4 opElongate( in vec3 p, in vec3 h )
{
    vec3 q = abs(p)-h;
    return vec4( max(q,0.0), min(max(q.x,max(q.y,q.z)),0.0) );
}

// Rotations
vec3 rotateY( in vec3 p, float t )
{
    float co = cos(t);
    float si = sin(t);
    p.xz = mat2(co,-si,si,co)*p.xz;
    return p;
}

vec3 rotateX( in vec3 p, float t )
{
    float co = cos(t);
    float si = sin(t);
    p.yz = mat2(co,-si,si,co)*p.yz;
    return p;
}
vec3 rotateZ( in vec3 p, float t )
{
    float co = cos(t);
    float si = sin(t);
    p.xy = mat2(co,-si,si,co)*p.xy;
    return p;
}

// Toolbox Functions
float cubicPulse(float c, float w, float x) {
  x = abs(x - c);
  if (x > w) {
    return 0.0;
  }
  x /= w;
  return 1.0 - x * x * (3.0 - 2.0 * x);
}

float bias(float b, float t) {
  return pow(t, log(b) / log(0.5));
}

float gain(float g, float t) {
  if (t < 0.5) {
    return bias(1.0 - g, 2.0 * t) / 2.0;
  }
  else {
    return 1.0 - bias(1.0 - g, 2.0 - 2.0 * t) / 2.0;
  }
}

// My SDFs
float sdHead(vec3 pos) {
  float d3 = sdSphere(pos - vec3(0.0, 0.8, 0.0), 1.1);
  float d4 = sdSphere(pos - vec3(0.0, 1.6, 0.0), 1.5);

  float head = opSmoothIntersection(d3, d4, 0.2);

  return head;
}

float sdArm(vec3 pos, vec3 dim, float angle1, float angle2) {
  vec3 q = rotateZ(pos, angle1);
  float d = sdEllipsoid(q, dim);

  q = rotateZ(pos, angle2);

  vec4 w = opElongate(q, vec3(1.0, 0.0 ,0.1));
  float d2 = w.w+sdCappedCylinder(w.xyz, vec2(0.4,0.3));

  float t = opSmoothIntersection(d, d2, 0.1);

  return t;
}


// SceneMap (no object type)
float sceneMap3D(vec3 pos) {

  // Body
  float d1 = sdEllipsoid(pos, vec3(1.2, 3.5, 1.2));
  float d2 = sdSphere(pos - vec3(0.0, 1.8, 0.0), 2.0);
  float body = opSmoothSubtraction(d2, d1, 0.3);

  // Subtract left arm
  float tArmSubl = sdArm((pos - vec3(1.0, -1.5, 0.0)), vec3(0.3, 1.6, 0.6), -0.2, 1.35);
  body = opSmoothSubtraction(tArmSubl, body, 0.1);

  // Subtract right arm
  float tArmSubr = sdArm((pos - vec3(-1.0, -1.5, 0.0)), vec3(0.3, 1.6, 0.6), 0.2, -1.35);
  body = opSmoothSubtraction(tArmSubr, body, 0.1);



  //Head 
  float head = sdHead(pos);
  
  float t1 = min(body, head); // Union
  // max(-t2, t1); // Subtraction
  // max(t2, t1); // Intersection

  // Face 
  float d3 = sdSphere(pos - vec3(0.0, 0.6, 0.0), 0.9);
  float d4 = sdSphere(pos - vec3(0.0, 1.4, 0.0), 1.3);

  float face = opSmoothIntersection(d3, d4, 0.2);

  t1 = sminCubic(t1, face, 0.1);

  // Left Arm
  float time = 0.0;
  float time2 = 0.0;
  if (u_Anim) {
    time = gain(smoothstep(-0.9, 0.9, sin(u_Time / 20.0)), 0.28);
    time2 = gain(smoothstep(-2.0, 0.1, sin(u_Time / 20.0)), 0.28);
  }

  float tArml1 = sdArm((pos - vec3(1.6 - time2, -1.5, 0.0)), vec3(0.2, 1.5, 0.5), 0.2 - time, -1.35 - time);
  float tArml2 = sdArm((pos - vec3(1.5 - time2, -1.5, 0.0)), vec3(0.1, 1.4, 0.4), 0.2 - time, -1.35 - time);

  float leftArm = opSmoothSubtraction(tArml2, tArml1, 0.1);


  // Right Arm
  float tArmr1 = sdArm((pos - vec3(-1.6 + time2, -1.5, 0.0)), vec3(0.2, 1.5, 0.5), -0.2 + time, 1.35 + time);
  float tArmr2 = sdArm((pos - vec3(-1.5 + time2, -1.5, 0.0)), vec3(0.1, 1.4, 0.4), -0.2 + time, 1.35 + time);

  float rightArm = opSmoothSubtraction(tArmr2, tArmr1, 0.1);


  float t = min(leftArm, t1);
  t = min(t, rightArm);


  // Face 
  float d5 = sdSphere(pos - vec3(0.0, 0.75, -0.3), 0.9);
  float d6 = sdSphere(pos - vec3(0.0, 1.55, -0.3), 1.3);
  float d7 = sdSphere(pos - vec3(0.0, 1.0, 0.85), 2.0);

  float face2 = opSmoothIntersection(d5, d6, 0.2);
  face2 = opSmoothIntersection(face2, d7, 0.2);

  t = min(t, face2);

  return t;
}


// Scene Map with object type and bounding volume
void sceneMap3D(vec3 pos, out float t, out int obj) {
  
  t = 10.0;

  float bound = sdBox(pos + vec3(0.0, 0.7, 0.0), vec3(2.0, 2.8, 1.5));

  if (bound < t) {

    float boundHead = sdBox(pos + vec3(0.0, -1.0, 0.0), vec3(1.2, 0.9, 1.3));
    if (boundHead < t) {
      //Head 
      float head = sdHead(pos);
      if (head < t) {
        t = head;
        obj = 0;
      }

      // Face 
      float d3 = sdSphere(pos - vec3(0.0, 0.75, -0.3), 0.9);
      float d4 = sdSphere(pos - vec3(0.0, 1.55, -0.3), 1.3);
      float d5 = sdSphere(pos - vec3(0.0, 1.0, 0.85), 2.0);

      float face = opSmoothIntersection(d3, d4, 0.2);
      face = opSmoothIntersection(face, d5, 0.2);

      if (face < t) {
        t = face;
        obj = 1;
      }

      // Eyes
      //vec3 q = rotateZ(pos - vec3(0.27, 0.87, -1.0), 0.4);
      vec3 q = (pos - vec3(0.27, 0.87, -1.0)) * vec3(0.9, 1.4, 1.0);
      
      float time = 0.0;
      if (u_Anim) {
        time = sin(u_Time / 20.0) * 4.0;
      }
      float k = 0.0 - time;
      float c = cos(k * q.x);
      float s = sin(k * q.x);
      mat2  m = mat2(c, -s, s, c);
      vec2 mq = m * q.xy;
      q = vec3(q.x, mq.y, q.z);

      float d6 = length((q)) - 0.22;
      if (d6 < t) {
        //t = d6;
        obj = 2;
      }

      vec3 q2 = (pos - vec3(-0.27, 0.87, -1.0)) * vec3(0.9, 1.4, 1.0);

      k = 0.0 - time; 
      c = cos(k * q2.x);
      s = sin(k * q2.x);
      m = mat2(c, -s, s, c);
      mq = m * q2.xy;
      q2 = vec3(q2.x, mq.y, q2.z);

      float d7 = length((q2) ) - 0.22;
      if (d7 < t) {
        //t = d7;
        obj = 2;
      }
    }

    float boundBody = sdBox(pos + vec3(0.0, 1.65, 0.0), vec3(1.3, 1.9, 1.3));
    if (boundBody < t) {
      // Body
      float d1 = sdEllipsoid(pos, vec3(1.2, 3.5, 1.2));
      float d2 = sdSphere(pos - vec3(0.0, 1.8, 0.0), 2.0);
      float body = opSmoothSubtraction(d2, d1, 0.3);

      // Subtract left arm
      float tArmSubl = sdArm((pos - vec3(1.0, -1.5, 0.0)), vec3(0.3, 1.6, 0.6), -0.2, 1.35);
      body = opSmoothSubtraction(tArmSubl, body, 0.1);

      // Subtract right arm
      float tArmSubr = sdArm((pos - vec3(-1.0, -1.5, 0.0)), vec3(0.3, 1.6, 0.6), 0.2, -1.35);
      body = opSmoothSubtraction(tArmSubr, body, 0.1);

      

      if (body < t) {
        t = body;
        obj = 0;
      }
    }


    float boundLeftArm = sdBox(pos + vec3(-1.6, 1.65, 0.0), vec3(0.6, 1.5, 1.0));
    if (boundLeftArm < t) {

      float time = 0.0;
      float time2 = 0.0;
      if (u_Anim) {
        time = gain(smoothstep(-0.9, 0.9, sin(u_Time / 20.0)), 0.28);
        time2 = gain(smoothstep(-2.0, 0.1, sin(u_Time / 20.0)), 0.28);
      }
      
        // Left Arm
      float tArml1 = sdArm((pos - vec3(1.6 - time2, -1.5, 0.0)), vec3(0.2, 1.5, 0.5), 0.2 - time, -1.35 - time);
      float tArml2 = sdArm((pos - vec3(1.5 - time2, -1.5, 0.0)), vec3(0.1, 1.4, 0.4), 0.2 - time, -1.35 - time);

      float leftArm = opSmoothSubtraction(tArml2, tArml1, 0.1);

      if (leftArm < t) {
        t = leftArm;
        obj = 0;
      }
    }
    
    float boundRightArm = sdBox(pos + vec3(1.6, 1.65, 0.0), vec3(0.6, 1.5, 1.0));
    if (boundRightArm < t) {
        // Right Arm
      float time = 0.0;
      float time2 = 0.0;
      if (u_Anim) {
        time = gain(smoothstep(-0.9, 0.9, sin(u_Time / 20.0)), 0.28);
        time2 = gain(smoothstep(-2.0, 0.1, sin(u_Time / 20.0)), 0.28);
      }

      float tArmr1 = sdArm((pos - vec3(-1.6 + time2, -1.5, 0.0)), vec3(0.2, 1.5, 0.5), -0.2 + time, 1.35 + time);
      float tArmr2 = sdArm((pos - vec3(-1.5 + time2, -1.5, 0.0)), vec3(0.1, 1.4, 0.4), -0.2 + time, 1.35 + time);

      float rightArm = opSmoothSubtraction(tArmr2, tArmr1, 0.1);

      if (rightArm < t) {
        t = rightArm;
        obj = 0;
      }
    }

  }

}


vec3 calculateNormals(vec3 pos)
{
	vec2 eps = vec2(0.0, 0.002*1.0);
	vec3 n = normalize(vec3(
	sceneMap3D(pos + eps.yxx) - sceneMap3D(pos - eps.yxx),
	sceneMap3D(pos + eps.xyx) - sceneMap3D(pos - eps.xyx),
	sceneMap3D(pos + eps.xxy) - sceneMap3D(pos - eps.xxy)));
    
	return n;
}


float fresnel(float bias, float scale, float power, vec3 I, vec3 N)
{
    return bias + scale * pow(1.0 + dot(I, N), power);
}

float square_wave(float x, float freq, float amplitude) {
  float val = abs(mod(floor(x * freq), 2.0) * amplitude);
  return val;
}


vec3 computeMaterial(int obj, vec3 p, vec3 n, vec3 light, vec3 view) {
  //float t;
  vec3 color = vec3(0.0, 0.0, 0.0);
  if (obj == 0) {
    color = vec3(u_Red, u_Green, u_Blue) * vec3(0.9, 0.9, 0.9) * max(0.0, dot(n, light)); // * shadow(light, p, 0.1);
  }
  else if (obj == 1) {
    color = vec3(0.0, 0.0, 0.0) * max(0.0, dot(n, light)); // * shadow(light, p, 0.1);
  }
  else if (obj == 2) {
    float time = sin(u_Time);
    color = vec3(0.12, 0.56, 1.0) * max(0.0, dot(n, light)) * square_wave(p.y, 50.0, 1.0);
  }
  return color;
}



void main() {

  vec3 lightPos = vec3(8.0, 4.0, -15.0);

  vec3 forward = normalize(u_Ref - u_Eye);
  vec3 right = cross(forward, u_Up);


  float len = length(u_Ref - u_Eye);
  // tan(3.14159 * 0.125)
  vec3 V = u_Up * len * tan(1.0 / 2.0); // What is FOVY supposed to be?
  vec3 H = right * len * (u_Dimensions.x / u_Dimensions.y) * tan(1.0 / 2.0);

  vec3 p = u_Ref + fs_Pos.x * H + fs_Pos.y * V;
  vec3 dir = normalize(p - u_Eye);

  float t = 0.001;
  vec3 ray_p = u_Eye + t * dir;

  // Background Color
  vec3 night_sky = vec3(0.0, 0.0, 0.0);
  vec3 white = vec3(0.54, 0.0, 0.54);
  vec3 col = mix(night_sky, white, noised(vec2(fs_Pos.x, fs_Pos.y) * 3.0));


  for (int i = 0; i < 50; i++) {
    vec3 isect = u_Eye + t * dir;
    float dist = 10.0;
    int obj = -1;
    sceneMap3D(isect, dist, obj);

    if (dist <= 0.001) {
      //col = vec3(0.0, 0.0, 0.0);
      vec3 nor = calculateNormals(isect);
      vec3 lightDir = normalize(lightPos - isect);
      col = computeMaterial(obj, isect, nor, lightDir, normalize(u_Eye - isect));

      float diffuse = max(0.0, dot(lightDir, nor)) / 1.0;
      float specular = pow(diffuse, 200.);
      //float R = fresnel(0.2, 1.4, 2.0, isect, nor);
      float fresnel = 1.0 - max(0.0, dot(normalize(u_Eye - isect), nor));
      col = vec3(diffuse * col + specular*0.9 + fresnel * 0.7);
    }
    t += dist;
    
  }

  out_Col = vec4(col, 1.0);
}
