#include "repository.h"
#include "object.h"
#include "oid.h"
#include "config.h"
#include "geef.h"
#include <string.h>
#include <git2.h>

void geef_repository_free(ErlNifEnv *env, void *cd)
{
	geef_repository *grepo = (geef_repository *) cd;
	git_repository_free(grepo->repo);
}

void geef_odb_free(ErlNifEnv *env, void *cd)
{
	geef_odb *odb = (geef_odb *) cd;
	git_odb_free(odb->odb);
}

ERL_NIF_TERM
geef_repository_init(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int bare;
	git_repository *repo;
	geef_repository *res_repo;
	ErlNifBinary bin;
	ERL_NIF_TERM term_repo;

	if (!enif_inspect_iolist_as_binary(env, argv[0], &bin))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&bin))
		return geef_oom(env);

	bare = !enif_compare(argv[1], atoms.true);

	if (git_repository_init(&repo, (char *) bin.data, bare) < 0)
		return geef_error(env);

	res_repo = enif_alloc_resource(geef_repository_type, sizeof(geef_repository));
	res_repo->repo = repo;
	term_repo = enif_make_resource(env, res_repo);
	enif_release_resource(res_repo);

	return enif_make_tuple2(env, atoms.ok, term_repo);
}

ERL_NIF_TERM
geef_repository_open(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	git_repository *repo;
	geef_repository *res_repo;
	ErlNifBinary bin;
	ERL_NIF_TERM term_repo;

	if (!enif_inspect_iolist_as_binary(env, argv[0], &bin))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&bin))
		return geef_oom(env);

	if (git_repository_open(&repo, (char *) bin.data) < 0)
		return geef_error(env);

	res_repo = enif_alloc_resource(geef_repository_type, sizeof(geef_repository));
	res_repo->repo = repo;
	term_repo = enif_make_resource(env, res_repo);
	enif_release_resource(res_repo);

	return enif_make_tuple2(env, atoms.ok, term_repo);
}

ERL_NIF_TERM
geef_repository_discover(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	git_buf buf = {NULL};
	ErlNifBinary bin, path;
	int error;

	if (!enif_inspect_iolist_as_binary(env, argv[0], &bin))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&bin))
		return geef_oom(env);

	error = git_repository_discover(&buf, (char *) bin.data, 0, NULL);
	enif_release_binary(&bin);
	if (error < 0)
		return geef_error(env);

	if (!enif_alloc_binary(strlen(buf.ptr), &path))
		return geef_oom(env);

	memcpy(path.data, buf.ptr, path.size);

	return enif_make_tuple2(env, atoms.ok, enif_make_binary(env, &path));
}

ERL_NIF_TERM
geef_repository_path(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_repository *repo;
	const char *path;
	size_t len;
	ErlNifBinary bin;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	path = git_repository_path(repo->repo);
	len = strlen(path);

	if (!enif_alloc_binary(len, &bin))
		return geef_oom(env);

	memcpy(bin.data, path, len);
	return enif_make_binary(env, &bin);
}

ERL_NIF_TERM
geef_repository_workdir(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_repository *repo;
	const char *path;
	size_t len;
	ErlNifBinary bin;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (git_repository_is_bare(repo->repo))
		return atoms.error;

	path = git_repository_workdir(repo->repo);
	len = strlen(path);

	if (!enif_alloc_binary(len, &bin))
		return geef_oom(env);

	memcpy(bin.data, path, len);
	return enif_make_binary(env, &bin);

}

ERL_NIF_TERM
geef_repository_is_bare(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_repository *repo;
	int bare;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	bare = git_repository_is_bare(repo->repo);

	if (bare)
		return atoms.true;

	return atoms.false;

}

ERL_NIF_TERM
geef_repository_config(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_repository *repo;
	geef_config *cfg;
	ERL_NIF_TERM term_cfg;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	cfg = enif_alloc_resource(geef_config_type, sizeof(geef_config));
	if (git_repository_config(&cfg->config, repo->repo) < 0)
		return geef_error(env);

	term_cfg = enif_make_resource(env, cfg);
	enif_release_resource(cfg);

	return enif_make_tuple2(env, atoms.ok, term_cfg);
}

ERL_NIF_TERM
geef_repository_odb(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_repository *repo;
	geef_odb *odb;
	ERL_NIF_TERM term_odb;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	odb = enif_alloc_resource(geef_odb_type, sizeof(geef_odb));
	if (git_repository_odb(&odb->odb, repo->repo) < 0)
		return geef_error(env);

	term_odb = enif_make_resource(env, odb);
	enif_release_resource(odb);

	return enif_make_tuple2(env, atoms.ok, term_odb);
}

ERL_NIF_TERM
geef_odb_exists(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_odb *odb;
	ErlNifBinary bin;
	git_oid oid;
	int exists;

	if (!enif_get_resource(env, argv[0], geef_odb_type, (void **) &odb))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	git_oid_fromraw(&oid, bin.data);
	exists = git_odb_exists(odb->odb, &oid);

	return exists ? atoms.true : atoms.false;
}

ERL_NIF_TERM
geef_odb_write(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	git_otype type;
	git_oid oid;
	geef_odb *odb;
	ErlNifBinary contents, oid_bin;

	if (!enif_get_resource(env, argv[0], geef_odb_type, (void **) &odb))
		return enif_make_badarg(env);

	if (!enif_inspect_iolist_as_binary(env, argv[1], &contents))
		return enif_make_badarg(env);

	type = geef_object_atom2type(argv[2]);
	if (git_odb_write(&oid, odb->odb, contents.data, contents.size, type) < 0)
		return geef_error(env);

	if (geef_oid_bin(&oid_bin, &oid) < 0)
		return geef_oom(env);

	return enif_make_tuple2(env, atoms.ok, enif_make_binary(env, &oid_bin));
}
