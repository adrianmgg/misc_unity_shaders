#ifndef __UTIL_GLSL_STYLE_MODULO
#define __UTIL_GLSL_STYLE_MODULO

#define _mod_template(T) T mod(T x, T y) { \
	return x - y * floor(x/y); \
}
_mod_template(float1)
_mod_template(float2)
_mod_template(float3)
_mod_template(float4)
#undef _mod_template

#endif