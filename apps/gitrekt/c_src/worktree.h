#ifndef GEEF_WORKTREE_H
#define GEEF_WORKTREE_H

#include "erl_nif.h"
#include <git2.h>
#include "repository.h"

extern ErlNifResourceType *geef_worktree_type;

typedef struct {
	git_worktree *worktree;
	geef_repository *repo;
} geef_worktree;

void geef_worktree_free(ErlNifEnv *env, void *cd);

ERL_NIF_TERM geef_worktree_add(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_worktree_prune(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

#endif
