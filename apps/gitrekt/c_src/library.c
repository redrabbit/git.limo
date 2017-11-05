#include "erl_nif.h"
#include <git2.h>

ERL_NIF_TERM geef_library_version(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int major, minor, rev;

	git_libgit2_version(&major, &minor, &rev);

	return enif_make_tuple3(env, enif_make_int(env, major), enif_make_int(env, minor), enif_make_int(env, rev));
}
