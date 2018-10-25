#ifndef GEEF_DIFF_H
#define GEEF_DIFF_H

#include "erl_nif.h"
#include <git2.h>
#include "repository.h"

extern ErlNifResourceType *geef_diff_type;

typedef struct {
	git_diff *diff;
	geef_repository *repo;
} geef_diff;

void geef_diff_free(ErlNifEnv *env, void *cd);

ERL_NIF_TERM geef_diff_tree(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_diff_stats(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_diff_delta_count(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_diff_deltas(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_diff_format(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

#endif

