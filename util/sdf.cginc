#ifndef __UTIL_SDF_FUNCTIONS
#define __UTIL_SDF_FUNCTIONS

// these are all ported versions of code from here https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm

#include "glsl_style_modulo.cginc"

float sphereSDF(float3 p, float s) {
	return length(p) - s;
}

float boxSDF(float3 p, float3 b){
	float3 q = abs(p) - b;
	return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float boundingBoxSDF(float3 p, float3 b, float e) {
	p = abs(p)-b;
	float3 q = abs(p+e)-e;
	return min(min(
		length(max(float3(p.x,q.y,q.z),0.0))+min(max(p.x,max(q.y,q.z)),0.0),
		length(max(float3(q.x,p.y,q.z),0.0))+min(max(q.x,max(p.y,q.z)),0.0)),
		length(max(float3(q.x,q.y,p.z),0.0))+min(max(q.x,max(q.y,p.z)),0.0));
}

float3 translateSpace(float3 p, float3 t) {
	return p - t;
}
float3 repeatSpace(float3 p, float3 d) {
	return mod(p+0.5*d,d) - 0.5*d;
}

float opSmoothUnion( float d1, float d2, float k ) {
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return lerp( d2, d1, h ) - k*h*(1.0-h);
}

float opSmoothSubtraction( float d1, float d2, float k ) {
    float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
    return lerp( d2, -d1, h ) + k*h*(1.0-h);
}

float opSmoothIntersection( float d1, float d2, float k ) {
    float h = clamp( 0.5 - 0.5*(d2-d1)/k, 0.0, 1.0 );
    return lerp( d2, d1, h ) + k*h*(1.0-h);
}


// https://strangerintheq.github.io/sdf.html
float mengerSpongeSDF(float3 p, int iterations) {
	float4 z = float4(p, 2);
	float3 offset = float3(0.785,1.1,0.46);
	float scale = 2.3;
	for (int n = 0; n < iterations; n++) {
		z = abs(z);
		if (z.x < z.y) z.xy = z.yx;
		if (z.x < z.z) z.xz = z.zx;
		if (z.y < z.z) z.yz = z.zy;
		z = z*scale;
		z.xyz -= offset*(scale-1.0);
		if(z.z<-0.5*offset.z*(scale-1.0))z.z+=offset.z*(scale-1.0);
	}
	return (length(max(abs(z.xyz)-1,0))-0.05)/z.w;
}

float mandelbulbSDF(float3 pos, float power, int iterations){
	float Bailout = 8.0;
	float3 z = pos;
	float dr = 2.0;
	float r = 0.0;
	for (int i = 0; i < iterations; i++) {
		r = length(z);
		if (r > Bailout) break;
		float theta = acos(z.z/r);
		float phi = /*wass atan, is glsl atan actually atan2?*/atan2(z.y,z.x);
		dr = pow(r, power-1.0)*power*dr + 1.0;
		float zr = pow(r,power);
		theta = theta*power;
		phi = phi*power;
		z = zr*float3(sin(theta)*cos(phi), sin(phi)*sin(theta), cos(theta));
		z += pos;
	}
	return 0.5*log(r)*r/dr;
}

#endif