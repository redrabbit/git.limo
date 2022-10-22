#ifndef GEEF_REPOSTIORY_H
#define GEEF_REPOSTIORY_H

#include "erl_nif.h"
#include <git2.h>

#define MAXBUFLEN       1024

ERL_NIF_TERM geef_repository_init(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_repository_open(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_repository_discover(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_repository_path(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_repository_workdir(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_repository_is_bare(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_repository_is_empty(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_repository_odb(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_repository_index(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_repository_config(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_repository_set_head(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

void geef_repository_free(ErlNifEnv *env, void *cd);

extern ErlNifResourceType *geef_repository_type;

typedef struct {
    git_repository *repo;
} geef_repository;

#endif
