# AGENTS.md

# Project: KnockDown Casual Physics Game

## 1. 프로젝트 목표

이 프로젝트는 짧은 시간 동안 가볍게 즐길 수 있는 캐주얼 물리 퍼즐 게임을 개발하는 것을 목표로 한다.

플레이어는 제한된 횟수(Moves) 안에 발사체를 쏘아 구조물 위에 쌓인 모든 오브젝트를 바닥으로 떨어뜨려야 한다.

핵심 재미는 다음 세 가지다.

1. 조준 후 발사하는 즉각적인 손맛
2. 구조물이 연쇄적으로 무너지는 물리 효과
3. 제한된 발사 횟수 안에 퍼즐을 해결하는 전략성

게임은 Android와 iOS 출시를 최종 목표로 하며, 개발 중에는 Web 빌드를 활용해 빠르게 테스트할 수 있어야 한다.

---

# 2. 기술 방향

## 권장 기술

- Engine: Godot 4.x
- Language: GDScript
- Physics: Godot 3D Physics
- Rendering: Forward+ 또는 Mobile Renderer
- Target platforms:
  - Web
  - Android
  - iOS
- Version Control: Git + GitHub
- Development assistant: Codex
- Ads:
  - Android/iOS: Google AdMob
  - Web: 초기 버전에서는 광고 미적용 가능

---

# 3. 왜 Web App부터 따로 만들지 않는가

React, Phaser, Three.js 등으로 웹 버전을 먼저 만든 뒤 모바일 앱으로 변환하는 구조는 사용하지 않는다.

이 게임은 다음 요소에 의존한다.

- 3D 충돌
- Rigidbody 물리
- 회전하는 플랫폼
- 다수 오브젝트 간 충돌
- 발사체 궤적
- 구조물 붕괴
- 모바일 터치 입력
- 진동
- 광고 SDK
- 앱스토어 배포

따라서 일반 Web App 기술보다 게임 엔진을 사용하는 편이 적합하다.

Godot 프로젝트를 하나 만들고 다음과 같이 사용한다.

Godot Project
    ├── Web Export → 빠른 테스트 / 공유
    ├── Android Export → Google Play
    └── iOS Export → App Store

즉,

"Web → App 재개발"

이 아니라

"하나의 게임 프로젝트 → Web / Android / iOS 빌드"

구조를 사용한다.

---

# 4. 게임 콘셉트

## 기본 플레이

화면 하단에는 대포 또는 캐논이 위치한다.

플레이어는 구조물을 바라보며 발사한다.

구조물은 여러 개의 Block으로 이루어진다.

플레이어의 목표는 제한된 발사 횟수 안에 Target Block을 모두 플랫폼 아래로 떨어뜨리는 것이다.

예:

Moves: 12

Remaining Targets: 8

모든 Target이 떨어지면 Stage Clear.

Moves가 0인데 Target이 남아 있으면 Stage Fail.

---

# 5. 카메라

기본 카메라는 구조물과 발사체를 동시에 보기 쉬운 약간 위에서 내려다보는 3인칭 시점으로 한다.

예상 시점:

Camera
      \
       \
        Structure
        Platform

             Cannon

카메라 위치는 기본적으로 고정한다.

추후 다음 효과를 추가할 수 있다.

- 발사 순간 Camera Shake
- 충돌 순간 짧은 Zoom
- Stage Clear 시 Camera Orbit
- Slow Motion

---

# 6. 게임 플레이 입력

모바일 기준으로 설계한다.

## 조준

화면을 좌우로 Drag

→ Cannon Yaw 변경

화면을 위아래로 Drag

→ Cannon Pitch 변경

또는 더 단순한 UX:

Drag 시작 위치 → Drag 끝 위치

이 벡터를 이용하여 발사 방향을 결정한다.

## 발사

화면에서 손을 떼면 발사.

대안:

조준 상태 + 화면 하단 Fire 버튼.

초기 MVP에서는 Fire 버튼 방식을 우선 사용한다.

---

# 7. 발사체

초기 발사체는 Cannon Ball 하나만 구현한다.

Projectile 속성:

- mass
- speed
- radius
- impactForce
- restitution
- gravityScale

예:

mass = 2
speed = 18
impactForce = 12

향후 Projectile 확장 가능:

- Normal Ball
- Heavy Ball
- Bomb
- Split Ball
- Piercing Ball
- Bouncy Ball

MVP에서는 Normal Ball만 구현한다.

---

# 8. 구조물 시스템

구조물은 여러 개의 Block으로 구성된다.

Block은 Rigidbody3D 기반으로 구현한다.

Block 속성:

- blockType
- mass
- durability
- friction
- restitution
- isTarget
- scoreValue

---

# 9. Block 종류

## Normal Block

기본 블록.

- Durability: 1
- Normal Mass
- Normal Friction


## Heavy Block

잘 밀리지 않는 블록.

- Mass 증가
- Durability 증가


## Weak Block

충돌 시 쉽게 파괴된다.


## Explosive Block

강한 충돌 시 폭발하여 주변 블록에 힘을 가한다.


## Target Block

반드시 바닥으로 떨어뜨려야 하는 블록.


## Obstacle Block

떨어뜨릴 필요는 없지만 구조물을 지탱한다.

---

# 10. Block 상태

Block은 다음 상태를 가진다.

enum BlockState

IDLE
MOVING
FALLING
DESTROYED

플랫폼 아래 일정 Y 값보다 내려가면 FALLING 상태로 변경한다.

예:

kill_height = -3.0

block.position.y < kill_height

이면 Target 제거 처리.

---

# 11. 플랫폼

플랫폼은 구조물을 지탱하는 Stage Base다.

기본 플랫폼:

StaticBody3D

난이도에 따라 다음 변형을 사용할 수 있다.

## Static Platform

고정 플랫폼.


## Rotating Platform

일정 속도로 회전.

변수:

rotationSpeed


## Oscillating Platform

좌우 이동.


## Tilting Platform

일정 주기로 기울어진다.


## Shrinking Platform

시간이 지나면서 크기가 작아진다.


초기 MVP에서는

Static Platform
Rotating Platform

두 종류만 구현한다.

---

# 12. 난이도 설계

난이도는 단순히 Block 수만 늘리지 않는다.

여러 Parameter를 조합하여 만든다.

## Difficulty Parameters

- structureHeight
- blockCount
- heavyBlockRatio
- weakBlockRatio
- targetCount
- platformSize
- platformRotationSpeed
- projectileCount
- cannonDistance
- structureWidth
- structureLayers
- blockSpacing

---

# 13. 난이도 예시

## Level 1~10

Tutorial

- Static Platform
- Normal Block
- 낮은 구조물
- 8~12 Blocks
- Moves 충분


## Level 11~30

Basic

- 구조물 높이 증가
- Heavy Block 등장
- Moves 감소


## Level 31~50

Intermediate

- Rotating Platform 등장
- 비대칭 구조물
- Weak Block 등장


## Level 51~80

Advanced

- 빠른 Platform Rotation
- Heavy Block 증가
- Target Block이 중앙에 위치


## Level 81+

Challenge

- 복합 구조물
- 높은 Tower
- 작은 Platform
- 제한 Moves 감소
- 폭발 Block 등장

---

# 14. 레벨 데이터 구조

레벨은 코드에 하드코딩하지 않는다.

Resource 또는 JSON으로 관리한다.

권장:

res://data/levels/

level_001.tres
level_002.tres
level_003.tres

LevelData 예:

class_name LevelData
extends Resource

@export var level_id: int

@export var move_limit: int

@export var platform_type: String

@export var platform_rotation_speed: float

@export var cannon_distance: float

@export var blocks: Array[BlockData]

---

# 15. Block 배치 데이터

BlockData 예:

class_name BlockData
extends Resource

@export var block_type: String

@export var position: Vector3

@export var rotation: Vector3

@export var scale: Vector3

@export var is_target: bool

이를 이용하여 StageGenerator가 자동으로 구조물을 생성한다.

---

# 16. Procedural Level Generator

장기적으로 레벨을 수작업으로 만들지 않고 자동 생성 가능하도록 설계한다.

StageGenerator 입력:

Difficulty

출력:

LevelData

생성 Algorithm 예:

1. 플랫폼 크기 결정
2. 기본 Layer 수 결정
3. 각 Layer의 Block 개수 결정
4. Block Type 결정
5. Target Block 결정
6. 안정성 검사
7. Move Limit 계산

---

# 17. 레벨 구조 패턴

다음 구조 Template을 지원한다.

Tower

    []
    []
    []
    []


Pyramid

      []
    [] []
  [] [] []


Wall

[] [] []
[] [] []
[] [] []


Bridge

[]        []
[] [][][] []
[]        []


Fortress

[] [] [] []
[]      []
[] [] [] []


초기에는 Template 기반 Stage Generator를 사용한다.

---

# 18. Victory 조건

Stage Clear 조건:

remaining_targets == 0

Clear 시:

- 발사 정지
- Physics 1~2초 대기
- Victory Effect
- Score 표시
- 다음 Level 버튼

---

# 19. Fail 조건

moves == 0

AND

remaining_targets > 0

단, 마지막 Projectile이 움직이는 동안 바로 실패시키지 않는다.

Physics가 안정될 때까지 기다린다.

예:

velocity < threshold

상태가 1.5초 이상 유지되면 Result 판정.

---

# 20. Move 시스템

Shot 1회당 Moves 1 감소.

UI:

Moves
12

발사 순간:

moves -= 1

---

# 21. Score

MVP에서는 단순 점수를 사용한다.

기본:

block_drop = +100
remaining_move = +500

Stage Score:

Dropped Blocks Score
+
Remaining Move Bonus

---

# 22. Star Rating

Stage Clear 후 별 평가.

3 Stars

Moves 3회 이상 남음

2 Stars

Moves 1~2회 남음

1 Star

Moves 0회

---

# 23. 광고 수익화

광고 때문에 플레이 흐름이 깨지지 않도록 한다.

광고 종류:

- Interstitial
- Rewarded Ads

Banner 광고는 초기 버전에서는 사용하지 않는다.

---

# 24. Interstitial 정책

매 Stage마다 광고를 보여주지 않는다.

권장:

3~5 Stage 클리어마다 1회.

예:

Level 5
Level 10
Level 15

또는

last_ad_stage + 4

조건.

광고는 Stage Clear 화면과 다음 Stage 사이에 표시한다.

게임 플레이 도중 광고를 띄우지 않는다.

---

# 25. Rewarded Ads

다음 기능에 활용 가능:

Continue +3 Moves

또는

Restart Without Penalty

예:

Moves가 0

"광고를 보고 3 Moves 추가"

사용자 선택 방식으로 한다.

---

# 26. 광고 추상화

게임 코드가 AdMob SDK에 직접 의존하지 않도록 한다.

Interface:

AdManager

Functions:

show_interstitial()

show_rewarded(callback)

is_rewarded_available()

Web에서는 DummyAdManager 사용.

Mobile에서는 AdMobAdManager 사용.

---

# 27. 배경

밝고 쨍한 Casual Game Style.

기본 스타일:

- Blue Sky
- Bright Grass
- Saturated Colors
- Soft Shadows
- Cartoon Objects

Reference 느낌:

Theme Park
Toy World
Miniature City

---

# 28. Background Theme

Stage 구간별 Theme 변경 가능.

1~20

Sunny Park


21~40

Beach


41~60

Candy Land


61~80

Snow Village


81~100

Space Park


초기 MVP에서는 Sunny Park 하나만 사용한다.

---

# 29. 그래픽 방향

Realistic 스타일을 사용하지 않는다.

목표:

- Toy-like
- Rounded
- Colorful
- High Saturation
- Clear Silhouette
- Soft Lighting

Block은 멀리서도 구분되어야 한다.

---

# 30. Object 디자인

초기 Block은 Cylinder 또는 Box를 사용한다.

추천 스타일:

Red Cylinder
White Stripe
Simple Logo

하지만 특정 기존 게임의 디자인을 그대로 복제하지 않는다.

독자적인 Color / Shape / Icon을 사용한다.

---

# 31. Physics 원칙

Physics 재미가 게임의 핵심이다.

그러나 실제 물리보다 "재미있는 물리"를 우선한다.

필요하면 다음 값을 현실보다 과장한다.

- Impact Force
- Bounce
- Angular Velocity
- Explosion Force

---

# 32. Physics 안정성

Rigidbody가 너무 많으면 Mobile 성능이 떨어질 수 있다.

MVP Target:

동시 Active Rigidbody

30~60개

최대 권장:

100개 이하

Sleeping Rigidbody 사용.

---

# 33. Game State

GameManager 상태:

enum GameState

LOADING
READY
AIMING
PROJECTILE_ACTIVE
CHECKING_RESULT
CLEAR
FAIL
PAUSED

GameState를 명확하게 관리한다.

---

# 34. Scene 구성

Main.tscn

Game.tscn

Level.tscn

Block.tscn

Projectile.tscn

Cannon.tscn

HUD.tscn

ResultPopup.tscn

---

# 35. Scene Tree 예

Game

├── LevelManager
├── GameManager
├── Stage
│   ├── Platform
│   ├── Blocks
│   └── Environment
├── Cannon
├── Projectiles
├── CameraRig
└── HUD

---

# 36. 권장 디렉터리 구조

res://

assets/

    models/
    textures/
    materials/
    sounds/
    music/
    ui/

scenes/

    game/
    levels/
    blocks/
    projectiles/
    ui/

scripts/

    core/
    gameplay/
    physics/
    level/
    ui/
    ads/
    save/

data/

    levels/
    configs/

autoload/

    game_manager.gd
    save_manager.gd
    audio_manager.gd
    ad_manager.gd

tests/

---

# 37. 주요 클래스

GameManager

LevelManager

StageGenerator

Block

Projectile

Cannon

PlatformController

CameraController

HUDController

SaveManager

AdManager

AudioManager

---

# 38. Save 시스템

저장 정보:

current_level

highest_level

level_stars

sound_enabled

music_enabled

vibration_enabled

last_ad_stage

초기에는 local save만 사용한다.

Godot:

user://save.json

---

# 39. 게임 UI

Gameplay HUD:

Top Left

Moves


Top Center

Level


Top Right

Pause


Bottom

Cannon / Fire UI


Result:

Stage Clear

Stars

Score

Next

Retry

---

# 40. Mobile UX

버튼은 손가락으로 누르기 쉽게 한다.

최소 Touch Target:

약 48dp 이상

Safe Area 대응.

Notch 대응.

화면 비율:

9:16 기준

다음 비율도 대응:

19.5:9

20:9

iPad

---

# 41. 사운드

필수 Sound:

Cannon Fire

Block Hit

Block Drop

Block Collision

Stage Clear

Stage Fail

Button Click

---

# 42. Haptic

Mobile에서 다음 상황에 진동:

Fire

Strong Impact

Stage Clear

Setting에서 Off 가능.

---

# 43. 성능 목표

Target:

Android Mid-range

60 FPS

최소:

30 FPS

Physics Objects:

50개 기준 60 FPS 목표

---

# 44. MVP 범위

MVP에서는 다음만 구현한다.

- Cannon
- Projectile
- Block Physics
- Static Platform
- Rotating Platform
- Move Limit
- Target Block
- Stage Clear
- Stage Fail
- 20 Levels
- Save
- Basic UI
- Sound
- Web Build
- Android Build

광고는 Core Gameplay 완성 후 추가한다.

---

# 45. MVP에서 제외

다음 기능은 초기 버전에서 만들지 않는다.

- Login
- Online Account
- Multiplayer
- Ranking Server
- Cloud Save
- Skin Shop
- In-App Purchase
- Daily Mission
- Battle Pass
- Complex Particle System
- Large Open World

---

# 46. 개발 단계

## Phase 0

Project Bootstrap

목표:

Godot 프로젝트 생성

완료 조건:

빈 Game Scene 실행

---

## Phase 1

Physics Prototype

구현:

Platform

Block

Projectile

Cannon

목표:

Projectile이 Block을 밀어 떨어뜨림.

---

## Phase 2

Core Game Loop

구현:

Moves

Target Detection

Clear

Fail

Restart

Next Level

---

## Phase 3

Level System

구현:

LevelData

StageGenerator

10~20 Stage

---

## Phase 4

Gameplay Polish

구현:

Camera Shake

Particle

Sound

Haptic

Slow Motion

---

## Phase 5

Mobile UX

Android Export

Touch Control

Resolution 대응

Performance Test

---

## Phase 6

Monetization

AdManager

Interstitial

Rewarded Ads

---

## Phase 7

iOS

iOS Export

Xcode Project

Signing

TestFlight

---

# 47. Codex 작업 원칙

Codex는 한 번에 게임 전체를 구현하지 않는다.

작업 단위를 작게 나눈다.

BAD:

"이 게임 전체를 만들어라."

GOOD:

"Projectile.tscn과 projectile.gd를 구현하고 테스트 가능한 Physics Prototype을 만들어라."

---

# 48. Codex 작업 순서

Codex는 작업 시작 전 반드시 다음을 수행한다.

1. AGENTS.md 읽기
2. 기존 Project 구조 확인
3. 현재 구현 상태 확인
4. 변경 대상 파일 목록 작성
5. 최소 변경으로 기능 구현
6. 실행 오류 점검
7. 변경 내용 요약

---

# 49. Codex 코드 수정 규칙

기존 동작을 이유 없이 변경하지 않는다.

한 Task에서 여러 시스템을 동시에 Rewrite하지 않는다.

새 기능 추가 시 기존 API를 최대한 유지한다.

Hard Coding을 최소화한다.

Game Balance 값은 Config 또는 Resource로 이동한다.

---

# 50. GDScript 스타일

Godot 4 문법 사용.

class_name 적극 활용.

Signal 기반 구조를 우선한다.

예:

signal projectile_fired
signal target_dropped
signal stage_cleared

Node 간 강한 참조를 최소화한다.

---

# 51. 게임 로직과 UI 분리

GameManager가 UI Node를 직접 조작하지 않는다.

BAD:

$HUD/MovesLabel.text = str(moves)

GOOD:

signal moves_changed(value)

HUD가 signal을 구독.

---

# 52. Physics와 Game Logic 분리

Block의 Rigidbody 물리는 Block에서 처리한다.

Stage Clear 판단은 GameManager에서 처리한다.

Projectile은 충돌 결과만 Signal로 전달한다.

---

# 53. 플랫폼 구현 규칙

Rotating Platform은 AnimationPlayer보다 코드 기반 회전을 우선한다.

단 Physics 영향을 고려하여 AnimatableBody3D 사용을 검토한다.

---

# 54. 테스트 가능한 구조

각 핵심 Scene은 독립 실행 가능해야 한다.

예:

ProjectileTest.tscn

BlockPhysicsTest.tscn

PlatformRotationTest.tscn

---

# 55. Debug UI

Development Build에서는 다음 정보를 표시 가능하게 한다.

FPS

Active Rigidbody

Current State

Moves

Remaining Target

Projectile Velocity

F3 또는 Debug 버튼으로 Toggle.

Release에서는 비활성화.

---

# 56. Git Workflow

main

개발 안정 버전


develop

통합 개발


feature/*

기능 개발


예:

feature/projectile

feature/block-physics

feature/level-system

feature/ads

---

# 57. Commit 규칙

예:

feat: add projectile firing

feat: add rotating platform

fix: prevent premature stage fail

refactor: separate HUD from GameManager

data: add level 001-010

---

# 58. Codex Commit 원칙

하나의 기능 단위로 Commit한다.

관련 없는 변경을 하나의 Commit에 넣지 않는다.

---

# 59. Codex가 작업 후 보고할 내용

항상 다음 형식으로 보고한다.

Implemented

Changed Files

How It Works

How To Test

Known Issues

Next Recommended Task

---

# 60. 최초 Codex Task

다음 Task부터 시작한다.

Task:

Godot 4 프로젝트의 최소 Physics Prototype을 구현한다.

구현 항목:

1. Game.tscn 생성
2. Static Platform 생성
3. Rigidbody3D Block 10개 생성
4. Cannon 생성
5. Projectile 생성
6. Fire 버튼 생성
7. Projectile이 Block을 충돌시켜 Platform 밖으로 떨어뜨릴 수 있어야 함

완료 기준:

게임 실행

↓

Fire 버튼

↓

Projectile 발사

↓

Block 충돌

↓

Block이 물리적으로 움직이고 떨어짐

그래픽 Asset은 사용하지 않는다.

Primitive Mesh를 사용한다.

---

# 61. 두 번째 Codex Task

Core Game Loop 구현.

추가:

Moves

Target Block

Remaining Target

Stage Clear

Stage Fail

Restart

---

# 62. 세 번째 Codex Task

Level Data 시스템 구현.

Level Resource

Stage Generator

10 Levels

---

# 63. 네 번째 Codex Task

Rotating Platform 추가.

LevelData에서

platform_rotation_speed

설정 가능하게 구현.

---

# 64. 다섯 번째 Codex Task

Mobile 조준 시스템.

Touch Drag

Cannon Rotation

Aim Indicator

---

# 65. 여섯 번째 Codex Task

Game Feel 개선.

Camera Shake

Hit Particle

Drop Particle

Sound

Slow Motion

---

# 66. 일곱 번째 Codex Task

20 Level 구성.

난이도 Curve 적용.

---

# 67. 여덟 번째 Codex Task

Android Export.

실제 Device Test.

---

# 68. 아홉 번째 Codex Task

AdManager Interface 구현.

DummyAdManager

AdMobAdManager 분리.

---

# 69. 열 번째 Codex Task

Reward Ads 추가.

Fail 화면:

Watch Ad

+3 Moves

---

# 70. 장기 확장 아이디어

Power Ups

Special Projectile

Skins

Daily Challenge

Random Stage

Endless Mode

Boss Structure

Season Theme

Leaderboard

---

# 71. 가장 중요한 설계 원칙

이 게임의 핵심은 콘텐츠 양이 아니다.

핵심은

SHOT

↓

IMPACT

↓

COLLAPSE

↓

CHAIN REACTION

↓

SATISFACTION

이다.

따라서 새로운 기능보다 다음 요소를 먼저 개선한다.

Projectile 타격감

Block 붕괴

Camera Feedback

Sound

Particle

Physics Balance

---

# 72. Definition of Done

Feature는 다음 조건을 만족해야 완료다.

- Godot 실행 오류 없음
- 기존 기능 Regression 없음
- Desktop 실행 가능
- Web Export 구조를 깨지 않음
- Android 빌드 호환
- Magic Number 최소화
- Debug 출력 제거 또는 Debug Mode 한정
- 변경 내용 문서화
- 테스트 방법 명시

---

# 73. Agent 금지 사항

Codex는 다음 행동을 하지 않는다.

- 요청 없이 Engine 변경
- Godot 버전 변경
- 프로젝트 전체 Rewrite
- 검증 없이 Plugin 추가
- 광고 SDK를 Core Gameplay보다 먼저 구현
- 로그인 시스템 추가
- 서버 시스템 추가
- 불필요한 Design Pattern 도입
- 과도한 Abstraction
- Massive Refactoring

---

# 74. 현재 최우선 목표

현재 목표는 상용 게임 완성이 아니다.

첫 번째 목표:

"5분 안에 플레이해도 재미있는 Physics Prototype"

이다.

다음 검증이 가장 중요하다.

1. 발사하는 느낌이 재미있는가?
2. 구조물이 무너질 때 시원한가?
3. 한 판을 다시 하고 싶은가?
4. 10~30초 안에 한 Stage가 끝나는가?
5. 실패했을 때 다시 시도하고 싶은가?

이 조건을 만족한 후 콘텐츠와 광고를 확장한다.
