#ifndef GEEF_ODB_H
#define GEEF_ODB_H

#include "erl_nif.h"
#include <git2.h>

ERL_NIF_TERM geef_odb_hash(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_odb_exists(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_odb_read(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_odb_write(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_odb_write_pack(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

ERL_NIF_TERM geef_odb_get_writepack(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_odb_writepack_append(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_odb_writepack_commit(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

void geef_odb_free(ErlNifEnv *env, void *cd);
void geef_odb_writepack_free(ErlNifEnv *env, void *cd);

extern ErlNifResourceType *geef_odb_type;
extern ErlNifResourceType *geef_odb_writepack_type;

typedef struct {
    git_odb *odb;
} geef_odb;

typedef struct {
    git_odb_writepack *odb_writepack;
} geef_odb_writepack;

#endif
