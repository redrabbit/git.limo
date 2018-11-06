#ifndef GEEF_REFLOG_H
#define GEEF_REFLOG_H

#include "erl_nif.h"
#include <git2.h>

ERL_NIF_TERM geef_reflog_count(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_reflog_read(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_reflog_delete(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

#endif
