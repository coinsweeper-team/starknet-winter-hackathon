use dojo_starter::models::{Direction, Position, GameDifficulty, GameResult, Cell, Boards, BoardStatus, Achievements};
use origami_random::dice::{Dice, DiceTrait};
// use cartridge_vrf::IVrfProviderDispatcher;
// use cartridge_vrf::IVrfProviderDispatcherTrait;
// use cartridge_vrf::Source;

// define the interface
#[starknet::interface]
trait IActions<T> {
    fn spawn(ref self: T);
    fn move(ref self: T, direction: Direction);
    fn setup_board_status(ref self: T, difficulty: GameDifficulty, board_id: u32) -> u32;
    // fn reveal_cell(ref self: T, board_id: u32, cell_id: u32);
    // fn get_board_status(ref self: T, board_id: u32) -> BoardStatus;
    fn randomMineOrder(ref self: T, num_cells: u16, num_mines: u16) -> Array<u16>;
    fn addCurrency(ref self: T, amount: u32);
    fn spendCurrency(ref self: T, amount: u32);
    fn setup_cells(ref self: T, board_id: u32) -> u32;
    // fn randomCurrencyAmount(ref self: T, seed_diff: u32) -> DiceTrait;
    fn setup_game(ref self: T, difficulty: GameDifficulty) -> u32;

}

// dojo decorator
#[dojo::contract]
pub mod actions {
    // const VRF_PROVIDER_ADDRESS: starknet::ContractAddress = starknet::contract_address_const::<0x123>();

    use super::{IActions, Direction, Position, GameDifficulty, GameResult,  next_position};
    use starknet::{ContractAddress, get_caller_address};
    use dojo_starter::models::{Vec2, Moves, DirectionsAvailable, Cell, Boards, BoardStatus, Currency};

    use dojo::model::{ModelStorage, ModelValueStorage};
    use dojo::event::EventStorage;

    use origami_random::dice::{Dice, DiceTrait};
    use origami_random::deck::{Deck, DeckTrait};

    // use cartridge_vrf::IVrfProviderDispatcher;
    // use cartridge_vrf::IVrfProviderDispatcherTrait;
    // use cartridge_vrf::Source;

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    pub struct Moved {
        #[key]
        pub player: ContractAddress,
        pub direction: Direction,
    }

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {

        

        fn spendCurrency(ref self: ContractState, amount: u32) {
            let mut world = self.world_default();
            let player = get_caller_address();
            let mut currency: Currency = world.read_model(player);
            currency.amount -= amount;
            world.write_model(@currency);
        }

        fn addCurrency(ref self: ContractState, amount: u32) {
            let mut world = self.world_default();
            let player = get_caller_address();
            let mut currency: Currency = world.read_model(player);
            currency.amount += amount;
            world.write_model(@currency);
        }

        // fn randomCurrencyAmount(ref self: ContractState, seed_diff: u32) -> DiceTrait {
        //     let player = get_caller_address();
        //     let s1: felt252 = player.into();
        //     let s2: felt252 = seed_diff.into();
        //     let seed: felt252 = s1 + s2;
            
        //     // subject to change, to be more general
        //     // 1/60 - 5, 1/40 - 4, 1/30 - 3, 1/20 - 2, 1/10 - 1
        //     // x <= 2 - 5, x <= 5 - 4, x <= 9 - 3, x <= 15 - 2, x <= 27 - 1, x > 27 - 0
        //     let mut dice = DiceTrait::new(120, player.into());
        //     return dice;
        // }

        fn randomMineOrder(ref self: ContractState, num_cells: u16, num_mines: u16) -> Array<u16> {
            let player = get_caller_address();
            // let vrf_provider = IVrfProviderDispatcher { contract_address: starknet::contract_address_const::<0x123>() };
            let mut mine_ids: Felt252Dict<u16> = Default::default();
            let mut count = num_mines;
            let mut ret_arr: Array<u16> = array![];

            let mut dice = DiceTrait::new(255, player.into());
            let mut dice_small = DiceTrait::new(8, player.into());
            
            while count > 0 {
                // let mine_id: u16 = deck.draw().into();
                // let random_value: u256 = vrf_provider.consume_random(Source::Nonce(player)).into();
                let random_value: u16 = dice.roll().into() * dice_small.roll().into();
                let rv = random_value % num_cells + 1;
                if mine_ids.get(rv.into()) == 0 {
                    mine_ids.insert(rv.into(), 1);
                    ret_arr.append(rv);
                    count -= 1;
                }
            };

            // return array of size mine_count, each cell has some id 1 to n
            return ret_arr;
        }

        fn setup_game(ref self: ContractState, difficulty: GameDifficulty) -> u32 {
            let mut world = self.world_default();
            let mut boards: Boards = world.read_model(get_caller_address());
            
            let board_id: u32 = boards.last_board_id + 1;
            assert!(board_id == self.setup_board_status(difficulty, board_id), "Error setting up board status");
            
            assert!(board_id == self.setup_cells(board_id), "Error setting up cells");
            
            // boards.boards_ids.append(board_id);
            boards.last_board_id = board_id;
            boards.played_total += 1;
            world.write_model(@boards);

            return board_id;
        }

        fn setup_board_status(ref self: ContractState, difficulty: GameDifficulty, board_id: u32) -> u32 {
            let mut world = self.world_default();
            let player = get_caller_address();
            
            let (width, height, mines) = match difficulty {
                GameDifficulty::Beginner => (8_u8, 8_u8, 10_u16),
                GameDifficulty::Intermediate => (16_u8, 16_u8, 40_u16),
                GameDifficulty::Expert => (30_u8, 16_u8, 99_u16),
            }; 

            let board = BoardStatus {
                player,
                board_id,
                difficulty: GameDifficulty::Beginner.into(),
                width,
                height,
                num_mines: mines,
                num_closed: (width * height).into(),
                is_over: false,
                time_elapsed: 0,
                // total_currency_available: 0,
                result: GameResult::Ongoing.into(),
            };

            // let board_id = 0; //world.write_model(@board.board_id);

            world.write_model(@board);

            return board_id;
        }

        fn setup_cells(ref self: ContractState, board_id: u32) -> u32 {
            let mut world = self.world_default();
            let board: BoardStatus = world.read_model((get_caller_address(), board_id));
            
            let total_cells = board.num_closed;
            let num_mines = board.num_mines;

            let mut i: u16 = 1;
            
            let mut mine_ids = self.randomMineOrder(total_cells, num_mines);
            let mut mine_ids_dict: Felt252Dict<u16> = Default::default();
            loop {
                match mine_ids.pop_front() {
                    Option::Some(k) => {
                        mine_ids_dict.insert(k.into(), 1);
                    },
                    Option::None => {
                        break;
                    },
                }
            };
            let mut world = self.world_default();
            let player = get_caller_address();

            // let vrf_provider = IVrfProviderDispatcher { contract_address: starknet::contract_address_const::<0x123>() };
            let mut dice = DiceTrait::new(120, player.into());
            
            loop {
                if i > total_cells {
                    break;
                }
                
                // let x: u8 = (i % width.into()).try_into().unwrap();
                // let y: u8 = (i / width.into()).try_into().unwrap();
                
                let is_bomb = mine_ids_dict.get(i.into()) == 1;
                
                // let random_value: u256 = vrf_provider.consume_random(Source::Nonce(player)).into();
                // let amount: u8 = (random_value % 120 + 1).try_into().unwrap();
                let amount: u8 = dice.roll().into();

                let mut amount_currency: u8 = 0;
                if amount <= 2 {
                    amount_currency = 5;
                } else if amount <= 5 {
                    amount_currency = 4;
                } else if amount <= 9 {
                    amount_currency = 3;
                } else if amount <= 15 {
                    amount_currency = 2;
                } else if amount <= 27 {
                    amount_currency = 1;
                } else {
                    amount_currency = 0;
                }

                let cell = Cell {
                    player,
                    board: board_id,
                    cell_id: i,
                    // location_x: x,
                    // location_y: y,
                    is_bomb,
                    amount_currency,
                };

                world.write_model(@cell);
                
                i += 1;
            };
            
            return board_id;
        }

        // fn reveal_cell(ref self: ContractState, board_id: u32, cell_id: u32) {
        //     let mut world = self.world_default();
        //     let player = get_caller_address();
            
        //     let cell: Cells = world.read_model((player, board_id, cell_id));
        //     let board: Board = world.read_model((player, board_id));
            
        //     assert(!board.is_over, 'Game is already over');
        //     assert(!cell.is_revealed, 'Cell already revealed');
            
        //     let updated_cell = Cells {
        //         player: cell.player,
        //         board: cell.board,
        //         cell_id: cell.cell_id,
        //         location_x: cell.location_x,
        //         location_y: cell.location_y,
        //         is_bomb: cell.is_bomb,
        //         is_revealed: true,
        //         is_clicked: true,
        //         neighbor_bombs: cell.neighbor_bombs,
        //     };
            
        //     if cell.is_bomb {
        //         let updated_board = Board {
        //             player: board.player,
        //             board_id: board.board_id,
        //             width: board.width,
        //             height: board.height,
        //             num_mines: board.num_mines,
        //             is_over: true,
        //             time_elapsed: board.time_elapsed,
        //         };
        //         world.write_model(@updated_board);
        //     }
            
        //     world.write_model(@updated_cell);
        // }

        // fn get_board_status(ref self: ContractState, board_id: u32) -> BoardStatus {
        //     let mut world = self.world_default();
        //     let player = get_caller_address();
            
        //     let board: BoardStatus = world.read_model((player, board_id));
            
        //     let mut num_closed = 0_u8;
        //     let total_cells = (board.width * board.height).into();
        //     let mut i: u32 = 0;
            
        //     loop {
        //         if i >= total_cells {
        //             break;
        //         }
                
        //         let cell: Cell = world.read_model((player, board_id, i));
        //         if !cell.is_revealed {
        //             num_closed += 1;
        //         }
                
        //         i += 1;
        //     };
            
        //     BoardStatus {
        //         player,
        //         board_id,
        //         difficulty: 1_u8,
        //         num_mines: board.num_mines,
        //         num_closed,
        //         is_over: board.is_over,
        //         time_elapsed: board.time_elapsed,
        //     }
        // }


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
