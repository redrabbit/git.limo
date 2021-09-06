#include "odb.h"
#include "geef.h"
#include <string.h>
#include <git2.h>

typedef git_transfer_progress git_indexer_progress;

void geef_odb_free(ErlNifEnv *env, void *cd)
{
	geef_odb *odb = (geef_odb *)cd;
	git_odb_free(odb->odb);
}

void geef_odb_writepack_free(ErlNifEnv *env, void *cd)
{
	geef_odb_writepack *odb_writepack = (geef_odb_writepack *)cd;
	git_odb_free(odb_writepack->odb_writepack);
}

static int noop_indexer_progress_callback(const git_indexer_progress *progress, void *payload)
{
	return 0;
}

static int indexer_progress_from_map(ErlNifEnv *env, const ERL_NIF_TERM map_term, git_indexer_progress* progress)
{
	ERL_NIF_TERM total_objects;
	ERL_NIF_TERM indexed_objects;
	ERL_NIF_TERM received_objects;
	ERL_NIF_TERM local_objects;
	ERL_NIF_TERM total_deltas;
	ERL_NIF_TERM indexed_deltas;
	ERL_NIF_TERM received_bytes;

	if (!enif_get_map_value(env, map_term, atoms.indexer_total_objects, &total_objects))
		return -1;

	if (!enif_get_map_value(env, map_term, atoms.indexer_indexed_objects, &indexed_objects))
		return -1;

	if (!enif_get_map_value(env, map_term, atoms.indexer_received_objects, &received_objects))
		return -1;

	if (!enif_get_map_value(env, map_term, atoms.indexer_local_objects, &local_objects))
		return -1;

	if (!enif_get_map_value(env, map_term, atoms.indexer_total_deltas, &total_deltas))
		return -1;

	if (!enif_get_map_value(env, map_term, atoms.indexer_indexed_deltas, &indexed_deltas))
		return -1;

	if (!enif_get_map_value(env, map_term, atoms.indexer_received_bytes, &received_bytes))
		return -1;

	if (!enif_get_uint(env, total_objects, &progress->total_objects))
		return -1;

	if (!enif_get_uint(env, indexed_objects, &progress->indexed_objects))
		return -1;

	if (!enif_get_uint(env, received_objects, &progress->received_objects))
		return -1;

	if (!enif_get_uint(env, local_objects, &progress->local_objects))
		return -1;
	
	if (!enif_get_uint(env, total_deltas, &progress->total_deltas))
		return -1;

	if (!enif_get_uint(env, indexed_deltas, &progress->indexed_deltas))
		return -1;

	if (!enif_get_uint64(env, received_bytes, &progress->received_bytes))
		return -1;

	return 0;
}

static ERL_NIF_TERM indexer_progress_to_map(ErlNifEnv *env, git_indexer_progress* progress)
{
	ERL_NIF_TERM map_term;
	ERL_NIF_TERM keys[] = {
		atoms.indexer_total_objects,
		atoms.indexer_indexed_objects,
		atoms.indexer_received_objects,
		atoms.indexer_local_objects,
		atoms.indexer_total_deltas,
		atoms.indexer_indexed_deltas,
		atoms.indexer_received_bytes
	};
	ERL_NIF_TERM values[] = {
		enif_make_uint(env, progress->total_objects),
		enif_make_uint(env, progress->indexed_objects),
		enif_make_uint(env, progress->received_objects),
		enif_make_uint(env, progress->local_objects),
		enif_make_uint(env, progress->total_deltas),
		enif_make_uint(env, progress->indexed_deltas),
		enif_make_uint64(env, progress->received_bytes),
	};

	if (enif_make_map_from_arrays(env, keys, values, 7, &map_term) < 0)
		return geef_error(env); // TODO

	return map_term;
}

ERL_NIF_TERM
geef_odb_hash(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	ErlNifBinary bin, oid_bin;
	git_oid oid;
	git_otype type;

	type = geef_object_atom2type(argv[0]);
	if (type == GIT_OBJ_BAD)
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	error = git_odb_hash(&oid, bin.data, bin.size, type);
	if (error < 0)
	{
		enif_release_binary(&bin);
		return geef_error_struct(env, error);
	}

	enif_release_binary(&bin);

	if (geef_oid_bin(&oid_bin, &oid) < 0)
		return geef_oom(env);

	return enif_make_tuple2(env, atoms.ok, enif_make_binary(env, &oid_bin));
}

ERL_NIF_TERM
geef_odb_exists(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_odb *odb;
	ErlNifBinary bin;
	git_oid oid;
	int exists;

	if (!enif_get_resource(env, argv[0], geef_odb_type, (void **)&odb))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	git_oid_fromraw(&oid, bin.data);
	exists = git_odb_exists(odb->odb, &oid);

	return exists ? atoms.true : atoms.false;
}

ERL_NIF_TERM
geef_odb_read(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	ErlNifBinary bin;
	git_oid id;
	git_otype type;
	git_odb_object *obj;
	size_t size;
	char *data;
	geef_odb *odb;

	if (!enif_get_resource(env, argv[0], geef_odb_type, (void **)&odb))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	if (bin.size != GIT_OID_RAWSZ)
		return enif_make_badarg(env);

	git_oid_fromraw(&id, bin.data);

	error = git_odb_read(&obj, odb->odb, &id);
	if (error < 0)
		return geef_error_struct(env, error);

	type = git_odb_object_type(obj);

	size = git_odb_object_size(obj);
	if (enif_alloc_binary(size, &bin) < 0)
	{
		git_odb_object_free(obj);
		return geef_oom(env);
	}

	data = (char *)git_odb_object_data(obj);
	memcpy(bin.data, data, size);

	git_odb_object_free(obj);

	return enif_make_tuple3(env, atoms.ok, geef_object_type2atom(type), enif_make_binary(env, &bin));
}

ERL_NIF_TERM
geef_odb_write(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	git_otype type;
	git_oid oid;
	geef_odb *odb;
	ErlNifBinary contents, oid_bin;

	if (!enif_get_resource(env, argv[0], geef_odb_type, (void **)&odb))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &contents))
		return enif_make_badarg(env);

	type = geef_object_atom2type(argv[2]);
	error = git_odb_write(&oid, odb->odb, contents.data, contents.size, type);
	if (error < 0)
		return geef_error_struct(env, error);

	if (geef_oid_bin(&oid_bin, &oid) < 0)
		return geef_oom(env);

	return enif_make_tuple2(env, atoms.ok, enif_make_binary(env, &oid_bin));
}

ERL_NIF_TERM
geef_odb_write_pack(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	geef_odb *odb;
	ErlNifBinary bin;
	git_odb_writepack *writepack = NULL;
	void *progress_payload = NULL;
	git_indexer_progress progress = { 0 };

	if (!enif_get_resource(env, argv[0], geef_odb_type, (void **) &odb))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	error = git_odb_write_pack(&writepack, odb->odb, noop_indexer_progress_callback, progress_payload);
	if (error < 0)
		return geef_error_struct(env, error);

	error = writepack->append(writepack, bin.data, bin.size, &progress);
	if (error < 0)
		return geef_error_struct(env, error);

	error = writepack->commit(writepack, &progress);
	if (error < 0)
		return geef_error_struct(env, error);

	return atoms.ok;
}

ERL_NIF_TERM
geef_odb_get_writepack(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	geef_odb *odb;
	geef_odb_writepack *odb_writepack;
	ERL_NIF_TERM term_odb_writepack;
	void *progress_payload = NULL;

	if (!enif_get_resource(env, argv[0], geef_odb_type, (void **)&odb))
		return enif_make_badarg(env);

	odb_writepack = enif_alloc_resource(geef_odb_writepack_type, sizeof(geef_odb_writepack));
	error = git_odb_write_pack(&odb_writepack->odb_writepack, odb->odb, noop_indexer_progress_callback, progress_payload);
	if (error < 0)
		return geef_error_struct(env, error);

	term_odb_writepack = enif_make_resource(env, odb_writepack);
	enif_release_resource(odb_writepack);

	return enif_make_tuple2(env, atoms.ok, term_odb_writepack);
}

ERL_NIF_TERM
geef_odb_writepack_append(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	geef_odb_writepack *odb_writepack;
	ErlNifBinary bin;

	if (!enif_get_resource(env, argv[0], geef_odb_writepack_type, (void **)&odb_writepack))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	git_indexer_progress progress;
	if (indexer_progress_from_map(env, argv[2], &progress) < 0)
		return enif_make_badarg(env);

	error = odb_writepack->odb_writepack->append(odb_writepack->odb_writepack, bin.data, bin.size, &progress);
	if (error < 0)
		return geef_error_struct(env, error);

        return enif_make_tuple2(env, atoms.ok, indexer_progress_to_map(env, &progress));
}

ERL_NIF_TERM
geef_odb_writepack_commit(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	geef_odb_writepack *odb_writepack;

	if (!enif_get_resource(env, argv[0], geef_odb_writepack_type, (void **)&odb_writepack))
		return enif_make_badarg(env);

	git_indexer_progress progress = { 0 };
	if (indexer_progress_from_map(env, argv[1], &progress) < 0)
		return enif_make_badarg(env);

	error = odb_writepack->odb_writepack->commit(odb_writepack->odb_writepack, &progress);
	if (error < 0)
		return geef_error_struct(env, error);

        return enif_make_tuple2(env, atoms.ok, indexer_progress_to_map(env, &progress));
}