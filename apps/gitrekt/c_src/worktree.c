#include "geef.h"
#include "oid.h"
#include "worktree.h"
#include <string.h>
#include <git2.h>

void geef_worktree_free(ErlNifEnv *env, void *cd)
{
	geef_worktree *worktree = (geef_worktree *) cd;
	enif_release_resource(worktree->repo);
	git_worktree_free(worktree->worktree);
}

ERL_NIF_TERM
geef_worktree_add(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
#if LIBGIT2_VER_MAJOR > 0 || LIBGIT2_VER_MINOR >= 27
    ErlNifBinary name_bin, path_bin, ref_bin;
	int override, error;
	geef_repository *repo;
	geef_worktree *worktree;
	ERL_NIF_TERM worktree_term;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	worktree = enif_alloc_resource(geef_worktree_type, sizeof(geef_worktree));
	if (!worktree)
		return geef_oom(env);

	if (!enif_inspect_binary(env, argv[1], &name_bin))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&name_bin))
		return geef_oom(env);

	if (!enif_inspect_binary(env, argv[2], &path_bin))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&path_bin))
		return geef_oom(env);

	git_worktree_add_options opts = GIT_WORKTREE_ADD_OPTIONS_INIT;
	if (enif_is_identical(argv[3], atoms.undefined)) {
		override = 0;
	} else if (enif_inspect_binary(env, argv[3], &ref_bin)) {
		override = 1;
	} else {
		return enif_make_badarg(env);
	}

	if (override && !geef_terminate_binary(&ref_bin))
	    return atoms.error;

	git_reference *ref;
	if (override) {
		error = git_reference_lookup(&ref, repo->repo, (char *) ref_bin.data);
		if (error < 0)
			return geef_error_struct(env, error);
		// TODO
		//opts.ref = ref;
		enif_release_binary(&ref_bin);
	}

	error = git_worktree_add(&worktree->worktree, repo->repo, (char *) name_bin.data, (char *) path_bin.data, &opts);
	if (error < 0) {
		//enif_release_resource(worktree);
		return geef_error_struct(env, error);
	}

	enif_release_binary(&name_bin);
	enif_release_binary(&path_bin);

	if (override) {
		git_reference_free(ref);
		enif_release_binary(&ref_bin);
	}

	worktree_term = enif_make_resource(env, worktree);
	enif_release_resource(worktree);
	worktree->repo = repo;
	enif_keep_resource(repo);

	return enif_make_tuple2(env, atoms.ok, worktree_term);
#else
    ErlNifBinary bin;
	if (geef_string_to_bin(&bin, "libgit2 version >= 0.27.x required") < 0)
		return geef_oom(env);
	return enif_make_tuple2(env, atoms.error, enif_make_binary(env, &bin));
#endif
}

ERL_NIF_TERM
geef_worktree_prune(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
#if LIBGIT2_VER_MAJOR > 0 || LIBGIT2_VER_MINOR >= 27
	int error;
	geef_worktree *worktree;

	if (!enif_get_resource(env, argv[0], geef_worktree_type, (void **) &worktree))
		return enif_make_badarg(env);

	git_worktree_prune_options opts = GIT_WORKTREE_PRUNE_OPTIONS_INIT;
	opts.flags |= GIT_WORKTREE_PRUNE_VALID;

	error = git_worktree_prune(worktree->worktree, &opts);
	if (error < 0) {
		return geef_error_struct(env, error);
	}

	return atoms.ok;
#else
    ErlNifBinary bin;
	if (geef_string_to_bin(&bin, "libgit2 version >= 0.27.x required") < 0)
		return geef_oom(env);
	return enif_make_tuple2(env, atoms.error, enif_make_binary(env, &bin));
#endif
}
