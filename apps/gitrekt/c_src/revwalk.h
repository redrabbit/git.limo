#ifndef GEEF_REVWALK_H
#define GEEF_REVWALK_H

#include "erl_nif.h"
#include <git2.h>
#include "repository.h"

extern ErlNifResourceType *geef_revwalk_type;

typedef struct {
	git_revwalk *walk;
	geef_repository *repo;
} geef_revwalk;

void geef_revwalk_free(ErlNifEnv *env, void *cd);

ERL_NIF_TERM geef_revwalk_repository(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_revwalk_new(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_revwalk_next(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_revwalk_push(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_revwalk_sorting(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_revwalk_simplify_first_parent(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_revwalk_reset(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_revwalk_pack(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

#endif
