"""
Traducao dos campos de fazenda (linguagem de produtor) para a arvore de
arquivos de entrada que o RuFaS espera, por substituicao sobre o cenario
freestall original (nao os arquivos ``_poc``, que ja tem valores fixos).

Hipotese validada pela PoC manual em 2026-08-21 (ver CLAUDE.md, secao
"Nova frente" > "Resultado da PoC"). Este modulo automatiza o mesmo
processo, gerando arquivos isolados por ``simulation_id`` (convencao
``farm_<id>_*``) para que requisicoes nao colidam entre si nem
sobrescrevam os arquivos originais ou os ``_poc``.

Limitacao conhecida (Fase 1, ver CLAUDE.md): os arquivos gerados aqui
(input/data/.../farm_<id>_*.json, output/farm_<id>/) nao sao limpos
automaticamente. A convencao de nomes por id existe para permitir uma
rotina de limpeza futura, mas ela ainda nao foi implementada.
"""

import json
from dataclasses import dataclass
from pathlib import Path

RUFAS_ROOT = Path("/Users/leandro/projetoRuFaS/RuFaS")

BASE_ANIMAL = Path("input/data/animal/example_freestall_animal.json")
BASE_FIELD_1 = Path("input/data/field/example_small_field_corn_alf_silage.json")
BASE_FIELD_2 = Path("input/data/field/example_small_field_corn_grain_alf_hay.json")
BASE_CONFIG = Path("input/data/config/example_freestall_config.json")
BASE_METADATA = Path("input/metadata/example_freestall_dairy_metadata.json")
BASE_HERD_INIT_TASK = Path("input/data/tasks/herd_init_task.json")
BASE_SIM_TASK = Path("input/data/tasks/example_freestall_task.json")


@dataclass
class FarmInput:
    cow_num: int
    calf_num: int
    annual_milk_yield: float
    field_size_1: float
    field_size_2: float
    fips_county_code: int


def _read_json(relative_path: Path) -> dict:
    with open(RUFAS_ROOT / relative_path, encoding="utf-8") as f:
        return json.load(f)


def _write_json(relative_path: Path, data: dict) -> None:
    full_path = RUFAS_ROOT / relative_path
    full_path.parent.mkdir(parents=True, exist_ok=True)
    with open(full_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def farm_animal_path(simulation_id: str) -> Path:
    return Path(f"input/data/animal/farm_{simulation_id}_animal.json")


def farm_field_1_path(simulation_id: str) -> Path:
    return Path(f"input/data/field/farm_{simulation_id}_field_1.json")


def farm_field_2_path(simulation_id: str) -> Path:
    return Path(f"input/data/field/farm_{simulation_id}_field_2.json")


def farm_config_path(simulation_id: str) -> Path:
    return Path(f"input/data/config/farm_{simulation_id}_config.json")


def farm_metadata_path(simulation_id: str) -> Path:
    return Path(f"input/metadata/farm_{simulation_id}_metadata.json")


def farm_output_dir(simulation_id: str) -> Path:
    return Path(f"output/farm_{simulation_id}/")


def farm_animals_dir(simulation_id: str) -> Path:
    return farm_output_dir(simulation_id) / "animals"


def farm_logs_dir(simulation_id: str) -> Path:
    return farm_output_dir(simulation_id) / "logs"


def farm_herd_init_task_path(simulation_id: str) -> Path:
    return Path(f"input/data/tasks/farm_{simulation_id}_herd_init_task.json")


def farm_sim_task_path(simulation_id: str) -> Path:
    return Path(f"input/data/tasks/farm_{simulation_id}_sim_task.json")


def farm_herd_init_task_manager_metadata_path(simulation_id: str) -> Path:
    return Path(f"input/task_manager_metadata_farm_{simulation_id}_herd_init.json")


def farm_sim_task_manager_metadata_path(simulation_id: str) -> Path:
    return Path(f"input/task_manager_metadata_farm_{simulation_id}_sim.json")


def generate_input_files(simulation_id: str, farm: FarmInput) -> None:
    """Gera animal/field/config/metadata isolados por simulation_id.

    A entrada ``animal_population`` do metadata gerado aqui ainda aponta
    para o arquivo estatico padrao (nao usado pela task de herd init) —
    ``point_metadata_to_generated_population`` a atualiza depois, quando
    o arquivo real ja existir.
    """
    animal = _read_json(BASE_ANIMAL)
    animal["herd_information"]["cow_num"] = farm.cow_num
    animal["herd_information"]["calf_num"] = farm.calf_num
    animal["herd_information"]["annual_milk_yield"] = farm.annual_milk_yield
    _write_json(farm_animal_path(simulation_id), animal)

    field_1 = _read_json(BASE_FIELD_1)
    field_1["field_size"] = farm.field_size_1
    _write_json(farm_field_1_path(simulation_id), field_1)

    field_2 = _read_json(BASE_FIELD_2)
    field_2["field_size"] = farm.field_size_2
    _write_json(farm_field_2_path(simulation_id), field_2)

    config = _read_json(BASE_CONFIG)
    config["FIPS_county_code"] = farm.fips_county_code
    _write_json(farm_config_path(simulation_id), config)

    metadata = _read_json(BASE_METADATA)
    metadata["files"]["animal"]["path"] = str(farm_animal_path(simulation_id))
    metadata["files"]["field_1"]["path"] = str(farm_field_1_path(simulation_id))
    metadata["files"]["field_2"]["path"] = str(farm_field_2_path(simulation_id))
    metadata["files"]["config"]["path"] = str(farm_config_path(simulation_id))
    _write_json(farm_metadata_path(simulation_id), metadata)


def point_metadata_to_generated_population(simulation_id: str, animal_population_path: Path) -> None:
    metadata = _read_json(farm_metadata_path(simulation_id))
    metadata["files"]["animal_population"]["path"] = str(animal_population_path)
    _write_json(farm_metadata_path(simulation_id), metadata)


def write_herd_init_task(simulation_id: str) -> None:
    task = _read_json(BASE_HERD_INIT_TASK)
    task["tasks"][0]["metadata_file_path"] = str(farm_metadata_path(simulation_id))
    task["tasks"][0]["output_prefix"] = f"farm_{simulation_id}_herd_init"
    task["tasks"][0]["save_animals"] = True
    task["tasks"][0]["save_animals_directory"] = str(farm_animals_dir(simulation_id)) + "/"
    _write_json(farm_herd_init_task_path(simulation_id), task)

    wrapper = {
        "files": {
            "tasks": {
                "title": "Task manager data",
                "description": f"Herd initialization task for simulation {simulation_id}.",
                "path": str(farm_herd_init_task_path(simulation_id)),
                "type": "json",
                "properties": "tasks_properties",
            }
        }
    }
    _write_json(farm_herd_init_task_manager_metadata_path(simulation_id), wrapper)


def write_sim_task(simulation_id: str) -> None:
    task = _read_json(BASE_SIM_TASK)
    task["tasks"][0]["metadata_file_path"] = str(farm_metadata_path(simulation_id))
    task["tasks"][0]["output_prefix"] = f"farm_{simulation_id}"
    _write_json(farm_sim_task_path(simulation_id), task)

    wrapper = {
        "files": {
            "tasks": {
                "title": "Task manager data",
                "description": f"Simulation task for simulation {simulation_id}.",
                "path": str(farm_sim_task_path(simulation_id)),
                "type": "json",
                "properties": "tasks_properties",
            }
        }
    }
    _write_json(farm_sim_task_manager_metadata_path(simulation_id), wrapper)


def find_generated_population_file(simulation_id: str) -> Path:
    animals_dir = RUFAS_ROOT / farm_animals_dir(simulation_id)
    matches = sorted(animals_dir.glob("animal_population-*.json"))
    if not matches:
        raise FileNotFoundError(
            f"Herd init nao gerou animal_population em {animals_dir} para simulation_id={simulation_id}."
        )
    return farm_animals_dir(simulation_id) / matches[-1].name


def find_result_csv(simulation_id: str) -> Path | None:
    """O CSV de resultado NAO fica em farm_output_dir(simulation_id) — o
    diretorio de saida de cada task (csv_output_directory) e um campo por
    task com default fixo ``output/CSVs/`` no schema do RuFaS,
    independente do ``output_directory`` passado a ``TaskManager.start()``
    (esse so controla o log do proprio TaskManager). Descoberto rodando o
    fluxo real via API em 2026-08-27 — ver CLAUDE.md. A unica isolacao
    por simulation_id aqui vem do nome do arquivo (via output_prefix),
    nao do diretorio."""
    csvs_dir = RUFAS_ROOT / "output" / "CSVs"
    matches = sorted(csvs_dir.glob(f"farm_{simulation_id}_saved_variables_*.csv"))
    return matches[-1] if matches else None
