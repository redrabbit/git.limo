#include "geef.h"
#include "pack.h"
#include "repository.h"
#include "revwalk.h"
#include <string.h>
#include <git2.h>

void geef_pack_free(ErlNifEnv *env, void *pb)
{
	geef_pack *pack = (geef_pack *) pb;
	enif_release_resource(pack->repo);
	git_packbuilder_free(pack->pack);
}

ERL_NIF_TERM
geef_pack_new(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	geef_repository *repo;
	geef_pack *pack;
	ERL_NIF_TERM pack_term;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	pack = enif_alloc_resource(geef_pack_type, sizeof(geef_pack));
	if (!pack)
		return geef_oom(env);

	error = git_packbuilder_new(&pack->pack, repo->repo);
	if (error < 0) {
		enif_release_resource(pack);
		return geef_error_struct(env, error);
	}

	pack_term = enif_make_resource(env, pack);
	enif_release_resource(pack);
	pack->repo = repo;
	enif_keep_resource(repo);

	return enif_make_tuple2(env, atoms.ok, pack_term);
}

ERL_NIF_TERM
geef_pack_insert_commit(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	geef_pack *pack;
	ErlNifBinary bin;
	git_oid id;

	if (!enif_get_resource(env, argv[0], geef_pack_type, (void **)&pack))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	if (bin.size != GIT_OID_RAWSZ)
		return enif_make_badarg(env);

	git_oid_fromraw(&id, bin.data);

	error = git_packbuilder_insert_commit(pack->pack, &id);
	if (error < 0)
		return geef_error_struct(env, error);

	return atoms.ok;
}


ERL_NIF_TERM
geef_pack_insert_walk(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	geef_pack *pack;
	geef_revwalk *walk;

	if (!enif_get_resource(env, argv[0], geef_pack_type, (void **)&pack))
		return enif_make_badarg(env);

	if (!enif_get_resource(env, argv[1], geef_revwalk_type, (void **)&walk))
		return enif_make_badarg(env);

	error = git_packbuilder_insert_walk(pack->pack, walk->walk);
	if (error < 0)
		return geef_error_struct(env, error);

	return atoms.ok;
}

ERL_NIF_TERM
geef_pack_data(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	git_buf buf = {NULL, 0, 0};
	ErlNifBinary data;
	geef_pack *pack;

	if (!enif_get_resource(env, argv[0], geef_pack_type, (void **)&pack))
		return enif_make_badarg(env);

	error = git_packbuilder_write_buf(&buf, pack->pack);
	if (error < 0)
		return geef_error_struct(env, error);

	if (!enif_alloc_binary(buf.size, &data)) {
		git_buf_free(&buf);
		return geef_oom(env);
	}

	memcpy(data.data, buf.ptr, data.size);
	git_buf_free(&buf);

	return enif_make_tuple2(env, atoms.ok, enif_make_binary(env, &data));
}