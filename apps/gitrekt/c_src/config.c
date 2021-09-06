#include "config.h"
#include "geef.h"
#include <git2.h>

void geef_config_free(ErlNifEnv *env, void *cd)
{
	geef_config *cfg = (geef_config *) cd;
	git_config_free(cfg->config);
}

ERL_NIF_TERM
geef_config_open(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_config *cfg;
	ErlNifBinary bin;
	ERL_NIF_TERM term_cfg;
	int error;

	if (!enif_inspect_binary(env, argv[0], &bin))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&bin))
		return geef_oom(env);

	cfg = enif_alloc_resource(geef_config_type, sizeof(geef_config));
	error = git_config_open_ondisk(&cfg->config, (char *) bin.data);
	enif_release_binary(&bin);

	if (error < 0)
		return geef_error_struct(env, error);

	term_cfg = enif_make_resource(env, cfg);
	enif_release_resource(cfg);

	return enif_make_tuple2(env, atoms.ok, term_cfg);

}

static ERL_NIF_TERM extract(geef_config **cfg, ErlNifBinary *bin, ErlNifEnv *env, const ERL_NIF_TERM argv[])
{
	if (!enif_get_resource(env, argv[0], geef_config_type, (void **) cfg))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], bin))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(bin))
		return geef_oom(env);

	return atoms.ok;
}

ERL_NIF_TERM
geef_config_set_bool(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_config *cfg;
	ErlNifBinary bin;
	int error, val;
	ERL_NIF_TERM ret;

	ret = extract(&cfg, &bin, env, argv);
	if (ret != atoms.ok)
		return ret;

	val = !enif_compare(argv[2], atoms.true);

	error = git_config_set_bool(cfg->config, (char *) bin.data, val);
	enif_release_binary(&bin);

	if (error < 0)
		return geef_error_struct(env, error);

	return atoms.ok;
}

ERL_NIF_TERM
geef_config_get_bool(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_config *cfg;
	ErlNifBinary bin;
	int error, val;
	ERL_NIF_TERM ret;

	ret = extract(&cfg, &bin, env, argv);
	if (ret != atoms.ok)
		return ret;

	error = git_config_get_bool(&val, cfg->config, (char *) bin.data);
	enif_release_binary(&bin);

	if (error < 0)
		return geef_error_struct(env, error);

	ret = val ? atoms.true : atoms.false;
	return enif_make_tuple2(env, atoms.ok, ret);
}

ERL_NIF_TERM
geef_config_set_int(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_config *cfg;
	ErlNifBinary bin;
	ErlNifSInt64 val;
	int error;
	ERL_NIF_TERM ret;

	ret = extract(&cfg, &bin, env, argv);
	if (ret != atoms.ok)
		return ret;

	if (!enif_get_int64(env, argv[2], &val))
		return enif_make_badarg(env);

	error = git_config_set_int64(cfg->config, (char *) bin.data, val);
	enif_release_binary(&bin);

	if (error < 0)
		return geef_error_struct(env, error);

	return atoms.ok;
}

ERL_NIF_TERM
geef_config_get_string(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_config *cfg;
	ErlNifBinary bin, result;
	git_buf buf = { 0 };
	int error;
	ERL_NIF_TERM ret;

	ret = extract(&cfg, &bin, env, argv);
	if (ret != atoms.ok)
		return ret;

	error = git_config_get_string_buf(&buf, cfg->config, (char *) bin.data);
	enif_release_binary(&bin);

	if (error < 0)
		return geef_error_struct(env, error);

	error = geef_string_to_bin(&result, buf.ptr);
	git_buf_free(&buf);

	if (error < 0)
		return geef_oom(env);

	return enif_make_tuple2(env, atoms.ok, enif_make_binary(env, &result));
}

ERL_NIF_TERM
geef_config_set_string(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_config *cfg;
	ErlNifBinary bin, val;
	int error;
	ERL_NIF_TERM ret;

	ret = extract(&cfg, &bin, env, argv);
	if (ret != atoms.ok)
		return ret;

	if (!enif_inspect_binary(env, argv[2], &val))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&val))
		return geef_oom(env);

	error = git_config_set_string(cfg->config, (char *) bin.data, (char *) val.data);
	enif_release_binary(&bin);
	enif_release_binary(&val);

	if (error < 0)
		return geef_error_struct(env, error);

	return atoms.ok;
}
