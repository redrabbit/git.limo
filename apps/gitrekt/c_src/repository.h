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
ERL_NIF_TERM geef_repository_odb(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_repository_config(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_odb_exists(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_odb_write(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);


void geef_repository_free(ErlNifEnv *env, void *cd);
void geef_odb_free(ErlNifEnv *env, void *cd);

extern ErlNifResourceType *geef_repository_type;
extern ErlNifResourceType *geef_odb_type;

typedef struct {
    git_repository *repo;
} geef_repository;

typedef struct {
    git_odb *odb;
} geef_odb;

#endif
