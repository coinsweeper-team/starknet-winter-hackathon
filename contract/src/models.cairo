use starknet::{ContractAddress};

// COINSWEEPER //

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct BestRecords {
    #[key]
    player: ContractAddress,
    beginner_best_time: u64,
    intermediate_best_time: u64,
    expert_best_time: u64,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug)]
pub enum GameResult {
    Ongoing,
    Lost,
    Won,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Achievements {
    #[key]
    pub player: ContractAddress,
    pub won_10_games: bool,
    pub won_100_games: bool,
    pub won_first_game: bool,
    pub first_in_leaderboard: bool,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Currency {
    #[key]
    pub player: ContractAddress,
    pub amount: u32,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Cell {
    #[key]
    pub player: ContractAddress,
     #[key]
    board: u32,
    #[key]
    cell_id: u16,
    // location_x: u8,
    // location_y: u8,
    is_bomb: bool,
    amount_currency: u8,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Boards {
    #[key]
    player: ContractAddress,
    // boards_ids: Array<u32>,
    last_board_id: u32,
    played_total: u32,
    won_total: u32,
}


#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct BoardStatus {
    #[key]
    player: ContractAddress,
    #[key]
    board_id: u32,
    difficulty: u8,
    width: u8,
    height: u8,
    num_mines: u16,
    num_closed: u16,
    is_over: bool,
    time_elapsed: u64,
    // total_currency_available: u32,
    result: u8,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug)]
enum GameDifficulty {
    Beginner: (),
    Intermediate: (),
    Expert: (),
}


#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug)]
pub enum Direction {
    Left,
    Right,
    Up,
    Down,
}


#[derive(Copy, Drop, Serde, IntrospectPacked, Debug)]
pub struct Vec2 {
    pub x: u32,
    pub y: u32
}


impl GameDifficultyIntoFelt252 of Into<GameDifficulty, u8> {
    fn into(self: GameDifficulty) -> u8 {
        match self {
            GameDifficulty::Beginner => 1,
            GameDifficulty::Intermediate => 2,
            GameDifficulty::Expert => 3,
        }
    }
}

impl GameResultIntoFelt252 of Into<GameResult, u8> {
    fn into(self: GameResult) -> u8 {
        match self {
            GameResult::Ongoing => 0,
            GameResult::Lost => 1,
            GameResult::Won => 2,
        }
    }
}

impl DirectionIntoFelt252 of Into<Direction, felt252> {
    fn into(self: Direction) -> felt252 {
        match self {
            Direction::Left => 1,
            Direction::Right => 2,
            Direction::Up => 3,
            Direction::Down => 4,
        }
    }
}

impl OptionDirectionIntoFelt252 of Into<Option<Direction>, felt252> {
    fn into(self: Option<Direction>) -> felt252 {
        match self {
            Option::None => 0,
            Option::Some(d) => d.into(),
        }
    }
}

#[generate_trait]
impl Vec2Impl of Vec2Trait {
    fn is_zero(self: Vec2) -> bool {
        if self.x - self.y == 0 {
            return true;
        }
        false
    }

    fn is_equal(self: Vec2, b: Vec2) -> bool {
        self.x == b.x && self.y == b.y
    }
}

#[cfg(test)]
mod tests {
    use super::{Position, Vec2, Vec2Trait};

    #[test]
    fn test_vec_is_zero() {
        assert(Vec2Trait::is_zero(Vec2 { x: 0, y: 0 }), 'not zero');
    }

    #[test]
    fn test_vec_is_equal() {
        let position = Vec2 { x: 420, y: 0 };
        assert(position.is_equal(Vec2 { x: 420, y: 0 }), 'not equal');
    }
}
