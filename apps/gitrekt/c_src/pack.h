#ifndef GEEF_PACK_H
#define GEEF_PACK_H

#include "erl_nif.h"
#include <git2.h>
#include "repository.h"

extern ErlNifResourceType *geef_pack_type;

typedef struct {
    git_packbuilder* pack;
	geef_repository *repo;
} geef_pack;

void geef_pack_free(ErlNifEnv *env, void *cd);

ERL_NIF_TERM geef_pack_new(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_pack_insert_commit(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_pack_insert_walk(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_pack_data(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

#endif
