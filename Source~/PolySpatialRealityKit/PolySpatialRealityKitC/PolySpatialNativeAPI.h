// This file contains the definitive definition for the API between Unity and
// any target platform. Any change to this file requires that you re-generate all targets using the
// Tools/polyspatialPlatformConverter.

#ifndef NATIVE_POLYSPATIAL_API_H
#define NATIVE_POLYSPATIAL_API_H

#ifndef POLYSPATIAL_EXPORT
#define POLYSPATIAL_EXPORT __attribute__((visibility("default")))  __attribute__((__used__))
#endif

#ifdef __cplusplus
extern "C" {
#endif


typedef void (*SendHostCommand_t)(/* PolySpatialHostCommand */int command, int argCount, const void** const args, unsigned int* argSizes);

typedef struct
{
    SendHostCommand_t SendHostCommand;
} PolySpatialSimulationHostAPI;


typedef void (*SendClientCommand_t)(/* PolySpatialCommand */int command, int argCount, void** args, unsigned int* argSizes);

typedef struct
{
    SendClientCommand_t SendClientCommand;
} PolySpatialNativeAPI;

// This function needs to be defined on a per platform basis to return the
// actual platform interface implementation
extern void GetPolySpatialNativeAPI(/* PolySpatialNativeAPI* */ void* PolySpatialApi);
extern void POLYSPATIAL_EXPORT SetPolySpatialNativeAPIImplementation(/* const PolySpatialNativeAPI */const void* PolySpatialApi, int size);


#ifdef __cplusplus
}
#endif

#endif // NATIVE_POLYSPATIAL_API_H
