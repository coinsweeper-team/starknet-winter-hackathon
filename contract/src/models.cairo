use starknet::{ContractAddress};

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Moves {
    #[key]
    pub player: ContractAddress,
    pub remaining: u8,
    pub last_direction: Option<Direction>,
    pub can_move: bool,
}


// COINSWEEPER //

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Cells {
    #[key]
    pub player: ContractAddress,
     #[key]
    board: u32,
    #[key]
    cell_id: u32,
    location_x: u8,
    location_y: u8,
    is_bomb: bool,
    is_revealed: bool,
    is_clicked: bool,
    neighbor_bombs: u8,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Board {
    #[key]
    player: ContractAddress,
    #[key]
    board_id: u32,
    width: u8,
    height: u8,
    num_mines: u8,
    is_over: bool,
    time_elapsed: u64,
}


#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct BoardStatus {
    #[key]
    player: ContractAddress,
    #[key]
    board_id: u32,
    difficulty: u8,
    num_mines: u8,
    num_closed: u8,
    is_over: bool,
    time_elapsed: u64,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug)]
enum GameDifficulty {
    Beginner: (),
    Intermediate: (),
    Expert: (),
}

// COINSWEEPER //

#[derive(Drop, Serde, Debug)]
#[dojo::model]
pub struct DirectionsAvailable {
    #[key]
    pub player: ContractAddress,
    pub directions: Array<Direction>,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Position {
    #[key]
    pub player: ContractAddress,
    pub vec: Vec2,
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