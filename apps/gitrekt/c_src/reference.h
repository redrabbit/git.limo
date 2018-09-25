#ifndef GEEF_REFERENCE_H
#define GEEF_REFERENCE_H

#include "erl_nif.h"
#include <git2.h>

extern ErlNifResourceType *geef_ref_iter_type;

typedef struct {
	git_reference_iterator *iter;
	geef_repository *repo;
} geef_ref_iter;

ERL_NIF_TERM geef_reference_list(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_reference_peel(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_reference_to_id(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_reference_glob(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_reference_lookup(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_reference_resolve(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_reference_create(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_reference_delete(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_reference_dwim(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_reference_iterator(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_reference_next(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_reference_has_log(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

void geef_ref_iter_free(ErlNifEnv *env, void *cd);

#endif
