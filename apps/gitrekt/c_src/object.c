#include "geef.h"
#include "repository.h"
#include "object.h"
#include "oid.h"
#include <zlib.h>
#include <string.h>
#include <git2.h>

void geef_object_free(ErlNifEnv *env, void *cd)
{
	geef_object *obj = (geef_object *) cd;
	enif_release_resource(obj->repo);
	git_object_free(obj->obj);
}

ERL_NIF_TERM geef_object_type2atom(const git_otype type)
{
	switch(type) {
	case GIT_OBJ_COMMIT:
		return atoms.commit;
	case GIT_OBJ_TREE:
		return atoms.tree;
	case GIT_OBJ_BLOB:
		return atoms.blob;
	case GIT_OBJ_TAG:
		return atoms.tag;
	default:
		return atoms.error;
	}
}

git_otype geef_object_atom2type(ERL_NIF_TERM term)
{
	if (!enif_compare(term, atoms.commit))
		return GIT_OBJ_COMMIT;
	else if (!enif_compare(term, atoms.tree))
		return GIT_OBJ_TREE;
	else if (!enif_compare(term, atoms.blob))
		return GIT_OBJ_BLOB;
	else if (!enif_compare(term, atoms.tag))
		return GIT_OBJ_TAG;

	return GIT_OBJ_BAD;
}

ERL_NIF_TERM
geef_object_repository(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_object *obj;
	geef_repository *res_repo;
	ERL_NIF_TERM term_repo;

	if (!enif_get_resource(env, argv[0], geef_object_type, (void **) &obj))
		return enif_make_badarg(env);

	res_repo = obj->repo;
	term_repo = enif_make_resource(env, res_repo);

	return enif_make_tuple2(env, atoms.ok, term_repo);
}

ERL_NIF_TERM
geef_object_lookup(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_repository *repo;
	ErlNifBinary bin;
	git_oid id;
	geef_object *obj;
	ERL_NIF_TERM term_obj;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	if (bin.size < GIT_OID_RAWSZ)
		return enif_make_badarg(env);

	git_oid_fromraw(&id, bin.data);

	obj = enif_alloc_resource(geef_object_type, sizeof(geef_object));
	if (!obj)
		return geef_oom(env);

	if (git_object_lookup(&obj->obj, repo->repo, &id, GIT_OBJ_ANY) < 0) {
		enif_release_resource(obj);
		return geef_error(env);
	}

	term_obj = enif_make_resource(env, obj);
	enif_release_resource(obj);

	obj->repo = repo;
	enif_keep_resource(repo);

	return enif_make_tuple3(env, atoms.ok, geef_object_type2atom(git_object_type(obj->obj)), term_obj);
}

ERL_NIF_TERM
geef_object_id(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	ErlNifBinary bin;
	const git_oid *id;
	geef_object *obj;

	if (!enif_get_resource(env, argv[0], geef_object_type, (void **) &obj))
		return enif_make_badarg(env);

	id = git_object_id(obj->obj);

	if (geef_oid_bin(&bin, id) < 0)
		return geef_oom(env);

	return enif_make_tuple2(env, atoms.ok, enif_make_binary(env, &bin));
}

ERL_NIF_TERM
geef_object_zlib_inflate(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	ErlNifBinary bin;
    z_stream z;
    z.zalloc = Z_NULL;
    z.zfree = Z_NULL;
    z.opaque = Z_NULL;

	if (!enif_inspect_binary(env, argv[0], &bin))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&bin)) {
        enif_release_binary(&bin);
        return geef_oom(env);
    }

    char output[bin.size*2];

    z.avail_in = bin.size;
    z.next_in = bin.data;
    z.avail_out = bin.size*2;
    z.next_out = output;

    inflateInit(&z);
    inflate(&z, Z_NO_FLUSH);
    inflateEnd(&z);

    if (enif_alloc_binary(z.total_out, &bin) < 0)
        return -1;

    memcpy(bin.data, output, z.total_out);

	return enif_make_tuple3(env, atoms.ok, enif_make_binary(env, &bin), enif_make_ulong(env, z.total_in));
}
