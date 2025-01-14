use dojo_starter::models::{Direction, Position, GameDifficulty, Cells, Board, BoardStatus};

// define the interface
#[starknet::interface]
trait IActions<T> {
    fn spawn(ref self: T);
    fn move(ref self: T, direction: Direction);
    fn setup_board(ref self: T, difficulty: GameDifficulty) -> u32;
    fn reveal_cell(ref self: T, board_id: u32, cell_id: u32);
    fn get_board_status(ref self: T, board_id: u32) -> BoardStatus;

}

// dojo decorator
#[dojo::contract]
pub mod actions {
    use super::{IActions, Direction, Position, GameDifficulty,  next_position};
    use starknet::{ContractAddress, get_caller_address};
    use dojo_starter::models::{Vec2, Moves, DirectionsAvailable, Cells, Board, BoardStatus};

    use dojo::model::{ModelStorage, ModelValueStorage};
    use dojo::event::EventStorage;

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    pub struct Moved {
        #[key]
        pub player: ContractAddress,
        pub direction: Direction,
    }

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn setup_board(ref self: ContractState, difficulty: GameDifficulty) -> u32 {
            let mut world = self.world_default();
            let player = get_caller_address();
            
            let (width, height, mines) = match difficulty {
                GameDifficulty::Beginner => (8_u8, 8_u8, 10_u8),
                GameDifficulty::Intermediate => (16_u8, 16_u8, 40_u8),
                GameDifficulty::Expert => (30_u8, 16_u8, 99_u8),
            }; 

            let board = Board {
                player,
                board_id : 0,
                width,
                height,
                num_mines: mines,
                is_over: false,
                time_elapsed: 0,
            };

            let board_id = 0; //world.write_model(@board.board_id);

         

            world.write_model(@board);

            let total_cells = (width * height).into();
            let mut i: u32 = 0;
            
            loop {
                if i >= total_cells {
                    break;
                }
                
                let x: u8 = (i % width.into()).try_into().unwrap();
                let y: u8 = (i / width.into()).try_into().unwrap();
                
                let cell = Cells {
                    player,
                    board: board_id,
                    cell_id: i,
                    location_x: x,
                    location_y: y,
                    is_bomb: false,
                    is_revealed: false,
                    is_clicked: false,
                    neighbor_bombs: 0,
                };

                world.write_model(@cell);
                
                i += 1;
            };
            
            board_id
        }

        fn reveal_cell(ref self: ContractState, board_id: u32, cell_id: u32) {
            let mut world = self.world_default();
            let player = get_caller_address();
            
            let cell: Cells = world.read_model((player, board_id, cell_id));
            let board: Board = world.read_model((player, board_id));
            
            assert(!board.is_over, 'Game is already over');
            assert(!cell.is_revealed, 'Cell already revealed');
            
            let updated_cell = Cells {
                player: cell.player,
                board: cell.board,
                cell_id: cell.cell_id,
                location_x: cell.location_x,
                location_y: cell.location_y,
                is_bomb: cell.is_bomb,
                is_revealed: true,
                is_clicked: true,
                neighbor_bombs: cell.neighbor_bombs,
            };
            
            if cell.is_bomb {
                let updated_board = Board {
                    player: board.player,
                    board_id: board.board_id,
                    width: board.width,
                    height: board.height,
                    num_mines: board.num_mines,
                    is_over: true,
                    time_elapsed: board.time_elapsed,
                };
                world.write_model(@updated_board);
            }
            
            world.write_model(@updated_cell);
        }

         fn get_board_status(ref self: ContractState, board_id: u32) -> BoardStatus {
            let mut world = self.world_default();
            let player = get_caller_address();
            
            let board: Board = world.read_model((player, board_id));
            
            let mut num_closed = 0_u8;
            let total_cells = (board.width * board.height).into();
            let mut i: u32 = 0;
            
            loop {
                if i >= total_cells {
                    break;
                }
                
                let cell: Cells = world.read_model((player, board_id, i));
                if !cell.is_revealed {
                    num_closed += 1;
                }
                
                i += 1;
            };
            
            BoardStatus {
                player,
                board_id,
                difficulty: 1_u8,
                num_mines: board.num_mines,
                num_closed,
                is_over: board.is_over,
                time_elapsed: board.time_elapsed,
            }
        }


        fn spawn(ref self: ContractState) {
            // Get the default world.
            let mut world = self.world_default();

            // Get the address of the current caller, possibly the player's address.
            let player = get_caller_address();
            // Retrieve the player's current position from the world.
            let position: Position = world.read_model(player);

            // Update the world state with the new data.

            // 1. Move the player's position 10 units in both the x and y direction.
            let new_position = Position {
                player, vec: Vec2 { x: position.vec.x + 10, y: position.vec.y + 10 }
            };

            // Write the new position to the world.
            world.write_model(@new_position);

            // 2. Set the player's remaining moves to 100.
            let moves = Moves {
                player, remaining: 100, last_direction: Option::None, can_move: true
            };

            // Write the new moves to the world.
            world.write_model(@moves);
        }


        // Implementation of the move function for the ContractState struct.
        fn move(ref self: ContractState, direction: Direction) {
            // Get the address of the current caller, possibly the player's address.

            let mut world = self.world_default();

            let player = get_caller_address();

            // Retrieve the player's current position and moves data from the world.
            let position: Position = world.read_model(player);
            let mut moves: Moves = world.read_model(player);
            // if player hasn't spawn, read returns model default values. This leads to sub overflow afterwards.
            // Plus it's generally considered as a good pratice to fast-return on matching conditions.
            if !moves.can_move {
                return;
            }

            // Deduct one from the player's remaining moves.
            moves.remaining -= 1;

            // Update the last direction the player moved in.
            moves.last_direction = Option::Some(direction);

            // Calculate the player's next position based on the provided direction.
            let next = next_position(position, moves.last_direction);

            // Write the new position to the world.
            world.write_model(@next);

            // Write the new moves to the world.
            world.write_model(@moves);

            // Emit an event to the world to notify about the player's move.
            world.emit_event(@Moved { player, direction });
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Use the default namespace "dojo_starter". This function is handy since the ByteArray
        /// can't be const.
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"dojo_starter")
        }
    }
}

// Define function like this:
fn next_position(mut position: Position, direction: Option<Direction>) -> Position {
    match direction {
        Option::None => { return position; },
        Option::Some(d) => match d {
            Direction::Left => { position.vec.x -= 1; },
            Direction::Right => { position.vec.x += 1; },
            Direction::Up => { position.vec.y -= 1; },
            Direction::Down => { position.vec.y += 1; },
        }
    };
    position
}
