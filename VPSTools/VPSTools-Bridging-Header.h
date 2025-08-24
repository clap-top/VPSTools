//
//  VPSTools-Bridging-Header.h
//  SwiftUIApp
//
//  Created by Assistant on 2025/8/18.
//

#ifndef VPSTools_Bridging_Header_h
#define VPSTools_Bridging_Header_h

// Libbox Framework

// SingBox C Library Function Declarations
// These functions should be provided by the SingBox C library

// Instance management
void* singbox_create_instance(void);
int singbox_start_with_config(void* instance, const char* config);
int singbox_stop(void* instance);
void singbox_destroy_instance(void* instance);

// Status and information
int singbox_is_running(void* instance);
const char* singbox_get_version(void);
const char* singbox_get_last_error(void* instance);

// Statistics and monitoring
const char* singbox_get_stats(void* instance);
const char* singbox_get_connection_info(void* instance);

// Configuration
int singbox_update_config(void* instance, const char* config);

// Logging
int singbox_set_log_level(void* instance, const char* level);

// Memory management
void singbox_free_string(const char* str);

#endif /* VPSTools_Bridging_Header_h */
