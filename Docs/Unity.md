# Egg Dash — Unity 3D prototype

로블록스 스타일 블록 캐릭터와 단순한 파트 지형으로 만든 **싱글플레이 프로토타입**입니다. Steal An Egg의 알 운반·부화·펫 수익·강화 흐름을 참고했으며, 모든 캐릭터와 맵은 Unity 기본 도형으로 새로 구성합니다. Roblox와 관련 없는 독립 프로젝트입니다.

## 실행

1. Unity Hub에서 **Add project from disk**로 이 폴더를 선택합니다.
2. **Unity 6 LTS 6000.0.62f1**로 엽니다 (Built-in Render Pipeline).
3. 최초 임포트 후 `Assets/Scenes/EggDash.unity` 씬이 자동 생성됩니다. 자동 생성되지 않으면 메뉴 **Egg Dash → Create or Open Game Scene**을 실행합니다.
4. 씬을 열고 **Play**를 누릅니다. 맵과 캐릭터는 Play 시작 시 생성됩니다.

외부 에셋, 유료 패키지, 서버 설정이 필요하지 않습니다. 레거시 Input Manager를 사용합니다 (Active Input Handling: Input Manager 또는 Both).

## 조작과 목표

| 입력 | 기능 |
| --- | --- |
| WASD / 방향키 | 이동 |
| Space | 점프 |
| Left Shift | 달리기 |
| 마우스 오른쪽 버튼 + 이동 | 카메라 회전 |
| E | 가까운 알 가져오기 / 파란 HATCH 패드에서 부화 / 강화 패드 사용 |
| Esc | 일시정지 |

둥지에서 알을 가져와 여우 수호 동물의 추격을 피해 기지의 파란 HATCH 패드로 돌아오세요. E로 부화하면 3초 뒤 펫이 생깁니다. 펫 한 마리는 초당 $12를 벌어줍니다. 기지 오른쪽 트레드밀에서 속도를, 왼쪽 노란 패드에서 펫 수용량을 강화할 수 있습니다. 희귀 알은 속도 레벨 3부터 운반할 수 있으며 부화 보너스 $150를 줍니다. 수호 동물은 기지 안전 구역까지 추격하지 않습니다.

- 시작 자금 $100, 기본 펫 슬롯 3개
- 속도 강화 최대 10회, 기지 확장 최대 3회 (최대 12마리)
- 알은 8초 뒤 재생성, 잡히면 운반 중인 알을 잃고 기지로 복귀
- 재화·펫·강화는 PlayerPrefs에 10초마다 및 강화/부화/종료 시 저장
- 한글 OS 폰트가 있으면 한국어 UI, 없으면 영어 UI 사용

## 파일 구조

- `Assets/EggDash/Scripts/EggDashGame.cs`: 월드 생성, 이동, 카메라, 추격 AI, 경제, 저장, HUD
- `Assets/EggDash/Editor/ProjectSetup.cs`: 시작 씬 자동 생성과 Linux 빌드 메뉴 진입점
- `Docs/concept.png`: 구현 방향을 설명하는 생성형 콘셉트 이미지. **실행 스크린샷이 아니며 실제 프로토타입의 렌더링과 차이가 있습니다.**

## 빌드

Unity의 File → Build Profiles에서 PC 플랫폼을 선택합니다. Linux Build Support가 설치되어 있으면 아래 배치 빌드도 사용할 수 있습니다.

```bash
Unity -batchmode -projectPath "$PWD" \
  -executeMethod EggDash.Editor.ProjectSetup.BuildLinux -quit -logFile build.log
```

## 검증 상태와 범위

작성 환경에는 Unity Editor가 없어 **Unity 컴파일, Play Mode 및 실행 파일 빌드는 검증하지 못했습니다.** 저장소 구조, 설정 JSON, C# 구문 구조와 진행 흐름은 별도 검사했습니다. 실행 전 위 Unity 버전에서 임포트 및 플레이 확인이 필요합니다.

멀티플레이, 타 플레이어 알 훔치기, 거래, 온라인 저장, 사운드, 모바일 터치 조작은 포함하지 않습니다. 다른 기지는 맵 장식입니다. 현재 목표는 혼자서 핵심 성장 흐름을 플레이할 수 있는 첫 프로토타입입니다.

## 수동 플레이 점검

- 최초 실행 → WASD/점프/카메라 회전 및 지형 충돌 확인
- 둥지 E → 알 운반 → 여우에게 잡히면 알 소실과 기지 복귀
- 알 운반 → 파란 패드 E → 3초 후 펫 생성 → 초당 수익 증가
- 펫 슬롯이 찼을 때 추가 알 획득 차단 및 기지 확장 후 해제
- 속도 레벨 3 미만에서 희귀 알 차단, 강화 후 획득 및 부화 보너스
- Esc 중 이동·AI·부화·수익 정지, Resume 후 재개
- 종료 후 재실행 시 재화·강화·펫 복원
