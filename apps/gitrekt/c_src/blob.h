#ifndef GEEF_BLOB_H
#define GEEF_BLOB_H

#include "object.h"

ERL_NIF_TERM geef_blob_size(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM geef_blob_content(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]);

#endif
