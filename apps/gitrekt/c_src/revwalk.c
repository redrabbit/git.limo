#include "geef.h"
#include "oid.h"
#include "revwalk.h"
#include <string.h>
#include <git2.h>

void geef_revwalk_free(ErlNifEnv *env, void *cd)
{
	geef_revwalk *walk = (geef_revwalk *)cd;
	enif_release_resource(walk->repo);
	git_revwalk_free(walk->walk);
}

ERL_NIF_TERM
geef_revwalk_repository(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_revwalk *walk;
	geef_repository *res_repo;
	ERL_NIF_TERM term_repo;

	if (!enif_get_resource(env, argv[0], geef_revwalk_type, (void **)&walk))
		return enif_make_badarg(env);

	res_repo = walk->repo;
	term_repo = enif_make_resource(env, res_repo);

	return enif_make_tuple2(env, atoms.ok, term_repo);
}

ERL_NIF_TERM
geef_revwalk_new(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	geef_repository *repo;
	geef_revwalk *walk;
	ERL_NIF_TERM walk_term;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **)&repo))
		return enif_make_badarg(env);

	walk = enif_alloc_resource(geef_revwalk_type, sizeof(geef_revwalk));
	if (!walk)
		return geef_oom(env);

	error = git_revwalk_new(&walk->walk, repo->repo);
	if (error < 0)
	{
		enif_release_resource(walk);
		return geef_error_struct(env, error);
	}

	walk_term = enif_make_resource(env, walk);
	enif_release_resource(walk);
	walk->repo = repo;
	enif_keep_resource(repo);

	return enif_make_tuple2(env, atoms.ok, walk_term);
}

ERL_NIF_TERM
geef_revwalk_push(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	ErlNifBinary bin;
	geef_revwalk *walk;
	int hide;

	if (!enif_get_resource(env, argv[0], geef_revwalk_type, (void **)&walk))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	hide = !enif_compare(argv[2], atoms.true);

	if (hide)
		return git_revwalk_hide(walk->walk, (git_oid *)bin.data) ? geef_error(env) : atoms.ok;

	return git_revwalk_push(walk->walk, (git_oid *)bin.data) ? geef_error(env) : atoms.ok;
}

ERL_NIF_TERM
geef_revwalk_next(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	ErlNifBinary bin;
	geef_revwalk *walk;

	if (!enif_get_resource(env, argv[0], geef_revwalk_type, (void **)&walk))
		return enif_make_badarg(env);

	if (!enif_alloc_binary(GIT_OID_RAWSZ, &bin))
		return geef_oom(env);


	error = git_revwalk_next((git_oid *)bin.data, walk->walk);
	if (error < 0)
	{
		if (error == GIT_ITEROVER)
			return enif_make_tuple2(env, atoms.error, atoms.iterover);

		return geef_error_struct(env, error);
	}

	return enif_make_tuple2(env, atoms.ok, enif_make_binary(env, &bin));
}

ERL_NIF_TERM
geef_revwalk_sorting(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_revwalk *walk;
	ERL_NIF_TERM term, head = argv[1];
	unsigned int flags = 0;

	if (!enif_get_resource(env, argv[0], geef_revwalk_type, (void **)&walk))
		return enif_make_badarg(env);

	while (enif_get_list_cell(env, head, &term, &head))
	{
		if (!enif_compare(atoms.toposort, term))
			flags |= GIT_SORT_TOPOLOGICAL;
		else if (!enif_compare(atoms.timesort, term))
			flags |= GIT_SORT_TIME;
		else if (!enif_compare(atoms.reversesort, term))
			flags |= GIT_SORT_REVERSE;
		else
			return enif_make_badarg(env);
	}

	git_revwalk_sorting(walk->walk, flags);

	return atoms.ok;
}

ERL_NIF_TERM
geef_revwalk_simplify_first_parent(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_revwalk *walk;

	if (!enif_get_resource(env, argv[0], geef_revwalk_type, (void **)&walk))
		return enif_make_badarg(env);

	git_revwalk_simplify_first_parent(walk->walk);

	return atoms.ok;
}

ERL_NIF_TERM
geef_revwalk_reset(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_revwalk *walk;

	if (!enif_get_resource(env, argv[0], geef_revwalk_type, (void **)&walk))
		return enif_make_badarg(env);

	git_revwalk_reset(walk->walk);

	return atoms.ok;
}

ERL_NIF_TERM
geef_revwalk_pack(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	git_buf buf = {NULL, 0, 0};
	geef_revwalk *walk;
	git_packbuilder *pb;
	ErlNifBinary pack;
	int error;

	if (!enif_get_resource(env, argv[0], geef_revwalk_type, (void **)&walk))
		return enif_make_badarg(env);

	error = git_packbuilder_new(&pb, walk->repo->repo);
	if (error < 0)
		return geef_error_struct(env, error);

	error = git_packbuilder_insert_walk(pb, walk->walk);
	if (error < 0)
	{
		git_packbuilder_free(pb);
		return geef_error_struct(env, error);
	}

	error = git_packbuilder_write_buf(&buf, pb);
	git_packbuilder_free(pb);

	if (error < 0)
		return geef_error_struct(env, error);

	if (!enif_alloc_binary(buf.size, &pack))
	{
		git_buf_free(&buf);
		return geef_oom(env);
	}

	memcpy(pack.data, buf.ptr, pack.size);
	git_buf_free(&buf);

	return enif_make_tuple2(env, atoms.ok, enif_make_binary(env, &pack));
}
