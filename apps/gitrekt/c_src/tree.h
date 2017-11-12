#ifndef GEEF_TREE_H
#define GEEF_TREE_H

#include "object.h"

ERL_NIF_TERM geef_tree_byid(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_tree_bypath(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_tree_nth(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_tree_count(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

#endif
