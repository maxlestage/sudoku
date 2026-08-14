mod db;
mod entities;
mod sudoku;

use std::net::SocketAddr;

use axum::extract::{Path, Query, State};
use axum::http::StatusCode;
use axum::response::Json;
use axum::routing::{delete, get, post};
use axum::Router;
use sea_orm::DatabaseConnection;
use serde::Deserialize;
use serde_json::{json, Value};
use tower_http::cors::CorsLayer;
use tower_http::services::{ServeDir, ServeFile};

use sudoku::Difficulty;

#[derive(Clone)]
struct AppState {
    db: DatabaseConnection,
}

#[derive(Deserialize)]
struct PuzzleParams {
    size: Option<usize>,
    difficulty: Option<Difficulty>,
}

#[derive(Deserialize)]
struct DeviceParams {
    device_id: String,
}

#[derive(Deserialize)]
struct SaveGameBody {
    id: Option<i64>,
    device_id: String,
    size: i32,
    difficulty: String,
    state: Value,
}

type ApiError = (StatusCode, Json<Value>);

fn err(status: StatusCode, msg: &str) -> ApiError {
    (status, Json(json!({ "error": msg })))
}

fn db_err(_: sea_orm::DbErr) -> ApiError {
    err(StatusCode::INTERNAL_SERVER_ERROR, "db error")
}

async fn get_puzzle(Query(params): Query<PuzzleParams>) -> Result<Json<Value>, ApiError> {
    let size = params.size.unwrap_or(9);
    let difficulty = params.difficulty.unwrap_or(Difficulty::Medium);
    // Generation is CPU-bound backtracking; run it off the async executor.
    let puzzle = tokio::task::spawn_blocking(move || sudoku::generate(size, difficulty))
        .await
        .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "generation failed"))?
        .ok_or_else(|| err(StatusCode::BAD_REQUEST, "size must be 4 or 9"))?;
    Ok(Json(serde_json::to_value(puzzle).unwrap()))
}

async fn save_game(
    State(state): State<AppState>,
    Json(body): Json<SaveGameBody>,
) -> Result<Json<Value>, ApiError> {
    let id = db::upsert_game(
        &state.db,
        body.id,
        &body.device_id,
        body.size,
        &body.difficulty,
        &body.state,
    )
    .await
    .map_err(db_err)?
    .ok_or_else(|| err(StatusCode::NOT_FOUND, "game not found"))?;
    Ok(Json(json!({ "id": id })))
}

async fn list_games(
    State(state): State<AppState>,
    Query(params): Query<DeviceParams>,
) -> Result<Json<Value>, ApiError> {
    let games = db::list_games(&state.db, &params.device_id)
        .await
        .map_err(db_err)?;
    Ok(Json(json!({ "games": games })))
}

async fn get_game(
    State(state): State<AppState>,
    Path(id): Path<i64>,
) -> Result<Json<Value>, ApiError> {
    let game = db::get_game(&state.db, id)
        .await
        .map_err(db_err)?
        .ok_or_else(|| err(StatusCode::NOT_FOUND, "game not found"))?;
    Ok(Json(serde_json::to_value(game).unwrap()))
}

async fn delete_game(
    State(state): State<AppState>,
    Path(id): Path<i64>,
    Query(params): Query<DeviceParams>,
) -> Result<Json<Value>, ApiError> {
    let n = db::delete_game(&state.db, id, &params.device_id)
        .await
        .map_err(db_err)?;
    if n == 0 {
        return Err(err(StatusCode::NOT_FOUND, "game not found"));
    }
    Ok(Json(json!({ "deleted": id })))
}

async fn health() -> Json<Value> {
    Json(json!({ "status": "ok" }))
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();

    let db_path = std::env::var("DATABASE_PATH").unwrap_or_else(|_| "sudoku.db".into());
    let db = db::connect(&db_path).await.expect("failed to open database");
    let state = AppState { db };

    let static_dir = std::env::var("STATIC_DIR").unwrap_or_else(|_| "web/dist".into());
    let index = format!("{static_dir}/index.html");
    let spa = ServeDir::new(&static_dir).fallback(ServeFile::new(&index));

    let api = Router::new()
        .route("/health", get(health))
        .route("/puzzle", get(get_puzzle))
        .route("/games", post(save_game).get(list_games))
        .route("/games/:id", get(get_game))
        .route("/games/:id", delete(delete_game))
        .with_state(state);

    let app = Router::new()
        .nest("/api", api)
        .fallback_service(spa)
        .layer(CorsLayer::permissive());

    let port: u16 = std::env::var("PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(8080);
    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    tracing::info!("listening on {addr}");
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
