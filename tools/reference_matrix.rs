#[test]
fn export_godot_matrix() {
    let out = std::path::PathBuf::from(std::env::var("GODOT_FIXTURES").unwrap());
    std::fs::create_dir_all(&out).unwrap();
    for seed in [0, 1, 42, 4243, i64::MAX as u64, u64::MAX] {
        for scripted in [false, true] {
            let mut sim = load_simulation_with_seed(seed);
            let mut commands = Vec::new();
            if scripted {
                for (tick, task, who, object, action) in [
                    (0, 101, 1, "object.cottage_toilet", "affordance.use_toilet"),
                    (0, 102, 2, "object.cottage_toilet", "affordance.use_toilet"),
                    (10, 103, 1, "object.cottage_bed", "affordance.sleep"),
                    (40, 104, 1, "person.neighbour", "affordance.talk"),
                    (70, 105, 2, "object.village_noticeboard", "affordance.read_the_board"),
                    (110, 106, 1, "object.pargeter_seat", "affordance.take_seat"),
                    (160, 107, 2, "object.shop_counter", "affordance.get_the_shopping"),
                    (220, 108, 1, "object.cottage_stove", "affordance.make_a_meal"),
                    (270, 109, 2, "object.kings_head_bar", "affordance.order_drink"),
                ] {
                    commands.push((tick, PlayerCommand::QueueUseObject {task: PlayerTaskId(task), resident: SimId(who), object: DefinitionId::new(object), affordance: DefinitionId::new(action), priority: 0}));
                }
                commands.push((3, PlayerCommand::CancelPlayerTask {task: PlayerTaskId(101)}));
                commands.push((20, PlayerCommand::CancelPlayerTask {task: PlayerTaskId(103)}));
                commands.push((300, PlayerCommand::QueueGoTo {task: PlayerTaskId(110), resident: SimId(1), destination: TilePosition {place: 0, x: 1, y: 1}, priority: 5}));
                commands.push((310, PlayerCommand::CancelPlayerTask {task: PlayerTaskId(999)}));
                commands.sort_by_key(|entry| entry.0);
            }
            let mut checkpoints = Vec::new();
            for tick in 0..=600 {
                if tick % 25 == 0 {
                    let mut saved = sim.save();
                    saved.event_ledger.clear();
                    checkpoints.push((tick, saved));
                }
                for (_, command) in commands.iter().filter(|entry| entry.0 == tick) {
                    sim.submit_player_command(command.clone());
                }
                if tick < 600 { sim.advance_tick(); }
            }
            let name = format!("matrix_{}_{}.ron", seed, if scripted {"orders"} else {"auto"});
            std::fs::write(out.join(name), ron::ser::to_string(&(seed.to_string(), commands, checkpoints, sim.event_ledger())).unwrap()).unwrap();
        }
    }
}
