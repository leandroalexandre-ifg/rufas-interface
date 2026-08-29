"""Orquestra o fluxo de duas etapas (herd init -> simulacao) validado pela
PoC, chamando ``TaskManager.start()`` do RuFaS diretamente em processo
(sem subprocess) — validado como seguro dentro de uma BackgroundTask do
FastAPI em 2026-08-27 (teste de fumaca, ver historico da sessao)."""

import os
import traceback
from pathlib import Path

from backend import farm_translation as ft


def _run_task_manager(metadata_path: Path, output_directory: Path, logs_directory: Path) -> None:
    from RUFAS.output_manager import LogVerbosity
    from RUFAS.task_manager import TaskManager

    TaskManager().start(
        metadata_path=metadata_path,
        verbosity=LogVerbosity.ERRORS,
        exclude_info_maps=False,
        output_directory=output_directory,
        logs_directory=logs_directory,
        clear_output_directory=False,
        produce_graphics=True,
        suppress_log_files=False,
        metadata_depth_limit=None,
    )


def run_full_simulation(simulation_id: str, farm: ft.FarmInput, job: dict) -> None:
    """Roda o fluxo completo para uma simulacao. Atualiza ``job`` (o dict de
    status compartilhado com a API) a cada etapa. Chamado de dentro do
    worker da fila serializada — nunca deve rodar duas instancias ao mesmo
    tempo (ver limitacao documentada no CLAUDE.md)."""
    original_cwd = Path.cwd()
    try:
        os.chdir(ft.RUFAS_ROOT)

        job["state"] = "running_herd_init"
        ft.generate_input_files(simulation_id, farm)
        ft.write_herd_init_task(simulation_id)
        _run_task_manager(
            metadata_path=ft.farm_herd_init_task_manager_metadata_path(simulation_id),
            output_directory=ft.farm_output_dir(simulation_id),
            logs_directory=ft.farm_logs_dir(simulation_id),
        )
        population_path = ft.find_generated_population_file(simulation_id)
        ft.point_metadata_to_generated_population(simulation_id, population_path)

        job["state"] = "running_simulation"
        ft.write_sim_task(simulation_id)
        _run_task_manager(
            metadata_path=ft.farm_sim_task_manager_metadata_path(simulation_id),
            output_directory=ft.farm_output_dir(simulation_id),
            logs_directory=ft.farm_logs_dir(simulation_id),
        )

        csv_path = ft.find_result_csv(simulation_id)
        if csv_path is None:
            raise FileNotFoundError(f"Simulacao terminou mas nenhum CSV de resultado foi encontrado (simulation_id={simulation_id}).")
        full_csv_path = ft.RUFAS_ROOT / csv_path
        job["csv_path"] = str(full_csv_path)
        job["csv_size_bytes"] = full_csv_path.stat().st_size
        job["state"] = "done"
    except Exception as e:
        job["state"] = "failed"
        job["error"] = f"{e}\n{traceback.format_exc()}"
    finally:
        os.chdir(original_cwd)
