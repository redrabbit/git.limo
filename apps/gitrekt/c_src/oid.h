#ifndef GEEF_OID_H
#define GEEF_OID_H

#include "erl_nif.h"
#include <git2.h>

ERL_NIF_TERM geef_oid_fmt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_oid_parse(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
int geef_oid_bin(ErlNifBinary *bin, const git_oid *id);

#endif
