#ifndef GEEF_CONFIG_H
#define GEEF_CONFIG_H

#include "erl_nif.h"
#include <git2.h>

void geef_config_free(ErlNifEnv *env, void *cd);
ERL_NIF_TERM geef_config_set_bool(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_config_get_bool(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_config_open(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_config_set_string(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_config_get_string(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

extern ErlNifResourceType *geef_config_type;

typedef struct {
	git_config *config;
} geef_config;

#endif
