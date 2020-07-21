#ifndef __UTIL_MAP_RANGE
#define __UTIL_MAP_RANGE

#define _map_range_func(ValueType, RangeType) ValueType map(ValueType value, RangeType oldMin, RangeType oldMax, RangeType newMin, RangeType newMax) { \
	return ((value - oldMin) / (oldMax - oldMin)) * (newMax - newMin) + newMin; \
}
_map_range_func(float1, float1)
_map_range_func(float2, float2)
_map_range_func(float3, float3)
_map_range_func(float4, float4)
#undef _map_range_func

#endif