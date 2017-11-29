#ifndef GEEF_OBJECT_H
#define GEEF_OBJECT_H

#include "erl_nif.h"
#include <git2.h>
#include "repository.h"

extern ErlNifResourceType *geef_object_type;

typedef struct {
	git_object *obj;
	geef_repository *repo;
} geef_object;

ERL_NIF_TERM geef_object_repository(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_object_lookup(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_object_id(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_object_zlib_inflate(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

ERL_NIF_TERM geef_object_type2atom(const git_otype type);

git_otype geef_object_atom2type(ERL_NIF_TERM term);
void geef_object_free(ErlNifEnv *env, void *cd);

#endif
