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

#endif