#include "geef.h"
#include "repository.h"
#include "graph.h"
#include "oid.h"
#include "signature.h"
#include <string.h>
#include <git2.h>
#include <git2/sys/commit.h>

ERL_NIF_TERM
geef_graph_ahead_behind(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
    int error;
    geef_repository *repo;
    ErlNifBinary bin;
    git_oid local, upstream;
    size_t ahead, behind;

    if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
        return enif_make_badarg(env);

    if (!enif_inspect_binary(env, argv[1], &bin))
        return enif_make_badarg(env);

    if (bin.size != GIT_OID_RAWSZ)
        return enif_make_badarg(env);

    git_oid_fromraw(&local, bin.data);

    if (!enif_inspect_binary(env, argv[2], &bin))
        return enif_make_badarg(env);

    if (bin.size != GIT_OID_RAWSZ)
        return enif_make_badarg(env);

    git_oid_fromraw(&upstream, bin.data);

    error = git_graph_ahead_behind(&ahead, &behind, repo->repo, &local, &upstream);
    if (error < 0)
		return geef_error_struct(env, error);

	return enif_make_tuple3(env, atoms.ok, enif_make_uint64(env, ahead), enif_make_uint64(env, behind));
}