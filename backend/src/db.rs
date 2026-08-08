use chrono::Utc;
use sea_orm::{
    ActiveModelTrait, ColumnTrait, ConnectionTrait, Database, DatabaseConnection, DbErr,
    EntityTrait, QueryFilter, QueryOrder, Schema, Set,
};
use serde::Serialize;

use crate::entities::{self, Entity as Games};

#[derive(Debug, Serialize)]
pub struct SavedGame {
    pub id: i64,
    pub device_id: String,
    pub size: i32,
    pub difficulty: String,
    pub state: serde_json::Value,
    pub updated_at: String,
}

impl From<entities::Model> for SavedGame {
    fn from(m: entities::Model) -> Self {
        SavedGame {
            id: m.id,
            device_id: m.device_id,
            size: m.size,
            difficulty: m.difficulty,
            state: serde_json::from_str(&m.state).unwrap_or(serde_json::Value::Null),
            updated_at: m.updated_at,
        }
    }
}

pub async fn connect(path: &str) -> Result<DatabaseConnection, DbErr> {
    let url = format!("sqlite://{path}?mode=rwc");
    let db = Database::connect(&url).await?;
    let backend = db.get_database_backend();
    let schema = Schema::new(backend);
    let mut stmt = schema.create_table_from_entity(Games);
    stmt.if_not_exists();
    db.execute(backend.build(&stmt)).await?;
    // Ignore duplicate-index errors on restart.
    for mut idx in schema.create_index_from_entity(Games) {
        idx.if_not_exists();
        let _ = db.execute(backend.build(&idx)).await;
    }
    Ok(db)
}

pub async fn upsert_game(
    db: &DatabaseConnection,
    id: Option<i64>,
    device_id: &str,
    size: i32,
    difficulty: &str,
    state: &serde_json::Value,
) -> Result<Option<i64>, DbErr> {
    let now = Utc::now().to_rfc3339();
    match id {
        Some(id) => {
            let existing = Games::find_by_id(id)
                .filter(entities::Column::DeviceId.eq(device_id))
                .one(db)
                .await?;
            let Some(existing) = existing else {
                return Ok(None);
            };
            let mut model: entities::ActiveModel = existing.into();
            model.size = Set(size);
            model.difficulty = Set(difficulty.to_owned());
            model.state = Set(state.to_string());
            model.updated_at = Set(now);
            let updated = model.update(db).await?;
            Ok(Some(updated.id))
        }
        None => {
            let model = entities::ActiveModel {
                device_id: Set(device_id.to_owned()),
                size: Set(size),
                difficulty: Set(difficulty.to_owned()),
                state: Set(state.to_string()),
                updated_at: Set(now),
                ..Default::default()
            };
            let inserted = model.insert(db).await?;
            Ok(Some(inserted.id))
        }
    }
}

pub async fn list_games(
    db: &DatabaseConnection,
    device_id: &str,
) -> Result<Vec<SavedGame>, DbErr> {
    let games = Games::find()
        .filter(entities::Column::DeviceId.eq(device_id))
        .order_by_desc(entities::Column::UpdatedAt)
        .all(db)
        .await?;
    Ok(games.into_iter().map(SavedGame::from).collect())
}

pub async fn get_game(db: &DatabaseConnection, id: i64) -> Result<Option<SavedGame>, DbErr> {
    Ok(Games::find_by_id(id).one(db).await?.map(SavedGame::from))
}

pub async fn delete_game(
    db: &DatabaseConnection,
    id: i64,
    device_id: &str,
) -> Result<u64, DbErr> {
    let res = Games::delete_many()
        .filter(entities::Column::Id.eq(id))
        .filter(entities::Column::DeviceId.eq(device_id))
        .exec(db)
        .await?;
    Ok(res.rows_affected)
}
