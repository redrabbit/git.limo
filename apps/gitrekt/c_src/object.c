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
    case GIT_OBJ_ANY:
        return atoms.undefined;
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
    else if (!enif_compare(term, atoms.undefined))
        return GIT_OBJ_ANY;

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

    if (bin.size != GIT_OID_RAWSZ)
        return enif_make_badarg(env);

    git_oid_fromraw(&id, bin.data);

    obj = enif_alloc_resource(geef_object_type, sizeof(geef_object));
    if (!obj)
        return geef_oom(env);

    if (git_object_lookup(&obj->obj, repo->repo, &id, GIT_OBJ_ANY) < 0)
        return geef_error(env);

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
    ERL_NIF_TERM chunks, chunk_str, data;
    int chunk_size = 16384;
    char chunk[chunk_size];
    int error;
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

    z.avail_in = bin.size;
    z.next_in = bin.data;

    if (inflateInit(&z) != Z_OK)
        return geef_oom(env);

    chunks = enif_make_list(env, 0);
    do {
        z.avail_out = chunk_size;
        z.next_out = chunk;

        error = inflate(&z, Z_SYNC_FLUSH);

        switch (error) {
            case Z_NEED_DICT:
                inflateEnd(&z);
                enif_release_binary(&bin);
                geef_string_to_bin(&bin, z.msg);
                return enif_make_tuple2(env, atoms.error, enif_make_tuple2(env, atoms.zlib_need_dict, enif_make_binary(env, &bin)));
            case Z_DATA_ERROR:
                inflateEnd(&z);
                enif_release_binary(&bin);
                geef_string_to_bin(&bin, z.msg);
                return enif_make_tuple2(env, atoms.error, enif_make_tuple2(env, atoms.zlib_data_error, enif_make_binary(env, &bin)));
            case Z_STREAM_ERROR:
                inflateEnd(&z);
                enif_release_binary(&bin);
                geef_string_to_bin(&bin, z.msg);
                return enif_make_tuple2(env, atoms.error, enif_make_tuple2(env, atoms.zlib_stream_error, enif_make_binary(env, &bin)));
            case Z_MEM_ERROR:
                inflateEnd(&z);
                return geef_oom(env);
        }

        if (!enif_realloc_binary(&bin, chunk_size-z.avail_out)) {
            inflateEnd(&z);
            return geef_oom(env);
        }
        memmove(bin.data, chunk, bin.size);
        chunks = enif_make_list_cell(env, enif_make_binary(env, &bin), chunks);

    } while (z.avail_out == 0);

    inflateEnd(&z);

    if(enif_make_reverse_list(env, chunks, &data) < 0) {
        return geef_oom(env);
    }

    return enif_make_tuple3(env, atoms.ok, data, enif_make_ulong(env, z.total_in));
}
