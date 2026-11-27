"""Run once against server_data with the lobby and match workers stopped."""

import argparse
import hashlib
import json
import os
from pathlib import Path
from tempfile import TemporaryDirectory


OLD_NAME = "Hermes Psychopompus"
GOD_NAME = "Hermes Psychopompos"
MIGRATION_DIR = ".hermes_psychopompos_v1"
POOL_SECTIONS = ("lists", "pending", "quarantined_lists")


def rename_field(record, field):
    if record.get(field) == OLD_NAME:
        record[field] = GOD_NAME


def rename_bot_label(record, field):
    label = record.get(field, "")
    if isinstance(label, str) and label.startswith(OLD_NAME + ": "):
        record[field] = GOD_NAME + label[len(OLD_NAME):]
    else:
        rename_field(record, field)


def deck_fingerprint(deck, parsed_numbers=False):
    composition = [deck.get(field, {}) for field in ("cards", "reinforcements", "special_setup")]
    serialized = json.dumps(composition, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    if parsed_numbers:
        # Godot parses JSON numbers as floats, even when the file contains integers.
        serialized = json.dumps(json.loads(serialized, parse_int=float), ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(serialized.encode("utf-8")).hexdigest()


def rename_deck(deck):
    for field in ("god", "god_name", "bot_god_name"):
        rename_field(deck, field)
    sections = [deck[field] for field in ("cards", "reinforcements") if OLD_NAME in deck.get(field, {})]
    if not sections:
        return
    saved_fingerprint = deck.get("fingerprint")
    parsed_numbers = saved_fingerprint is not None and saved_fingerprint != deck_fingerprint(deck)
    for counts in sections:
        copies = counts.pop(OLD_NAME)
        counts[GOD_NAME] = max(counts.get(GOD_NAME, 0), copies)
    if saved_fingerprint is not None:
        deck["fingerprint"] = deck_fingerprint(deck, parsed_numbers)


def migrate_match(match):
    for player in match.get("players", []):
        rename_field(player, "god_name")
        if player.get("session_id", "").strip().upper().startswith("BOT_"):
            rename_bot_label(player, "player_name")
            rename_bot_label(player, "deck_name")
    results = match.get("bot_deck_results", [])
    if "bot_deck_result" in match:
        results = [*results, match["bot_deck_result"]]
    for result in results:
        rename_deck(result)
        rename_bot_label(result, "bot_name")


def pool_entries(pool):
    for section in POOL_SECTIONS:
        yield from pool.get(section, [])
    if pool.get("challenger"):
        yield pool["challenger"]


def merge_pools(current, legacy):
    by_id = {entry["list_id"]: entry for entry in pool_entries(current)}
    for entry in pool_entries(legacy):
        existing = by_id.get(entry["list_id"])
        if existing is not None and any(
            existing.get(field) != entry.get(field)
            for field in existing.keys() | entry.keys() if field != "fingerprint"
        ):
            raise ValueError(f"Conflicting ranked bot snapshots for list {entry['list_id']}")
    for section in POOL_SECTIONS:
        current.setdefault(section, []).extend(entry for entry in legacy.get(section, []) if entry["list_id"] not in by_id)
    incumbent = legacy.get("quarantined_id", "")
    challenger = legacy.get("challenger", {})
    if challenger and challenger["list_id"] not in by_id:
        if current.get("challenger"):
            # A pool can run one trial at a time. Keep the other candidate's record in the queue.
            current["pending"].insert(0, challenger)
        else:
            current["challenger"] = challenger
            current["quarantined_id"] = incumbent
    current["quarantined_ids"] = list(dict.fromkeys(current.get("quarantined_ids", []) + legacy.get("quarantined_ids", [])))


def migrate_pool(state):
    pools = state.get("by_god", {})
    for name in (OLD_NAME, GOD_NAME):
        for entry in pool_entries(pools.get(name, {})):
            rename_deck(entry)
            for field in ("deck_name", "self_play_name"):
                rename_bot_label(entry, field)
    if OLD_NAME in pools:
        legacy = pools.pop(OLD_NAME)
        if GOD_NAME in pools:
            merge_pools(pools[GOD_NAME], legacy)
        else:
            pools[GOD_NAME] = legacy
    assigned = state.get("assigned_names", {})
    for list_id in assigned:
        rename_bot_label(assigned, list_id)


def migrate_store(relative_path, data):
    name = relative_path.name.removesuffix(".bak")
    if relative_path.parent.name == "match_history_results":
        migrate_match(data)
    elif relative_path.parent.name == "community_bot_pool":
        rename_deck(data)
        rename_bot_label(data, "deck_name")
    elif name == "match_history.json":
        for match in data.get("matches_by_id", {}).values():
            migrate_match(match)
    elif name in ("bot_pool_state.json", "bot_pool_state_bo3.json"):
        migrate_pool(data)
    elif name == "accounts.json":
        for account in data.get("accounts_by_id", {}).values():
            for portrait in account.get("rank_badges", {}).values():
                rename_field(portrait, "card")
    elif name == "account_decks.json":
        for decks in data.get("decks_by_account_id", {}).values():
            for deck in decks.values():
                rename_deck(deck)


def store_files(server_data):
    for name in ("match_history.json", "bot_pool_state.json", "bot_pool_state_bo3.json", "accounts.json", "account_decks.json"):
        for suffix in ("", ".bak"):
            path = server_data / (name + suffix)
            if path.is_file():
                yield path
    for directory in ("match_history_results", "community_bot_pool"):
        for pattern in ("*.json", "*.json.bak"):
            yield from sorted((server_data / directory).glob(pattern))


def migrate(server_data):
    backup_dir = server_data / MIGRATION_DIR
    marker = backup_dir / "complete"
    if marker.is_file():
        print("The Hermes ladder migration has already completed.")
        return
    sources = list(store_files(server_data))
    if not sources:
        raise ValueError(f"No recognized server data files in {server_data}")
    with TemporaryDirectory(prefix="hermes-stage-", dir=server_data) as temporary:
        staging = Path(temporary)
        changes = []
        for source in sources:
            original = source.read_bytes()
            if OLD_NAME.encode("utf-8") not in original:
                continue
            relative = source.relative_to(server_data)
            try:
                data = json.loads(original)
                before = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
                migrate_store(relative, data)
                after = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
            except (AttributeError, KeyError, TypeError, ValueError) as error:
                raise ValueError(f"{relative}: {error}") from error
            if before == after:
                continue
            staged = staging / relative
            staged.parent.mkdir(parents=True, exist_ok=True)
            staged.write_text(after, encoding="utf-8")
            changes.append(relative)

        for relative in changes:
            source = server_data / relative
            backup = backup_dir / "originals" / relative
            if not backup.exists():
                backup.parent.mkdir(parents=True, exist_ok=True)
                backup_temp = staging / "backup.tmp"
                backup_temp.write_bytes(source.read_bytes())
                os.replace(backup_temp, backup)
            os.replace(staging / relative, source)

        backup_dir.mkdir(exist_ok=True)
        marker_temp = staging / "complete"
        marker_temp.write_text("Hermes Psychopompos ladder migration complete.\n", encoding="utf-8")
        os.replace(marker_temp, marker)
    print(f"Updated {len(changes)} server files. Original files are backed up under {backup_dir}.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("server_data", type=Path, help="Path to server_runtime/server_data")
    args = parser.parse_args()
    try:
        migrate(args.server_data.resolve())
    except (OSError, ValueError) as error:
        parser.exit(1, f"Migration failed: {error}\n")


if __name__ == "__main__":
    main()
