import firebase_admin
from firebase_admin import credentials, auth, firestore
from firebase_functions import https_fn, options
import os
import secrets
from datetime import datetime, timedelta, timezone

# --- Firebase Admin SDK 초기화 ---
# Firebase Functions 환경에서는 자동으로 초기화되므로 명시적 설정이 필요 없을 수 있습니다.
# 하지만 안전을 위해, 이미 초기화되지 않았다면 초기화하도록 조건을 추가하는 것이 좋습니다.
if not firebase_admin._apps:
    firebase_admin.initialize_app()

db = firestore.client() # Firestore 클라이언트 초기화

# --- 환경 변수 설정 ---
# 이 변수들은 Firebase CLI를 통해 설정된 환경 변수를 가져옵니다.
# 로컬에서 테스트할 때 환경 변수가 설정되지 않았다면, 두 번째 인자로 제공된 기본값이 사용됩니다.
# (배포 시에는 Firebase CLI로 설정한 실제 값이 사용됩니다.)
# APP_DOMAIN은 Firebase Hosting을 배포한 후 할당된 실제 URL로 변경해야 합니다.
# 예: firebase functions:config:set app.domain="https://your-project-id.web.app"

# 사용자님의 프로젝트 ID를 기반으로 APP_DOMAIN 기본값을 설정합니다.
APP_DOMAIN = os.environ.get("APP_DOMAIN", "https://certificatestudyaiffelcore12th.web.app")

# SENDER_EMAIL은 Trigger Email Extension 설정 시 지정한 FROM address와 일치해야 합니다.
# 여기서는 Functions에서 이메일을 직접 보내는 것이 아니므로, 이 변수는 confirm_account_deletion 함수의 HTML 본문에만 사용됩니다.
# Trigger Email Extension이 대신 이메일을 보냅니다.
SENDER_EMAIL = os.environ.get("SENDER_EMAIL", "certificatestudy2025@gmail.com")


# --- HTTP 트리거 함수: 계정 삭제 요청 처리 ---
@https_fn.on_request(cors_origins=["*"]) # CORS 허용 (개발 단계에서만 사용, 실제 서비스는 특정 도메인만 허용)
def request_account_deletion(request: https_fn.Request):
    """
    클라이언트로부터 계정 삭제 요청을 받아, 확인 이메일 발송을 트리거합니다.
    이메일은 Trigger Email Extension을 통해 발송됩니다.
    """
    if request.method != 'POST':
        return https_fn.Response("POST requests만 허용됩니다.", status=405)

    try:
        request_json = request.get_json()
        user_id = request_json.get('id')
        user_email = request_json.get('email')

        if not user_id or not user_email:
            return https_fn.Response("'id' 또는 'email'이 누락되어 있습니다.", status=400)

        # 1. Firestore에서 ID에 해당하는 사용자 정보 조회 및 이메일 일치 확인
        # users 컬렉션에서 'id' 필드가 user_id와 일치하는 문서를 찾습니다.
        user_docs = db.collection('users').where('id', '==', user_id).limit(1).get()

        if not user_docs: # user_docs가 비어있다면 (ID를 찾지 못했다면)
            return https_fn.Response("그런 ID를 쓰는 회원은 없습니다.", status=404)

        found_user_data = user_docs[0].to_dict()
        stored_email = found_user_data.get('email')
        firebase_uid = user_docs[0].id # Firestore 문서 ID는 Firebase Auth UID와 동일

        if stored_email != user_email:
            return https_fn.Response("입력하신 E메일은 이 ID에 등록된 E메일이 아닙니다.", status=400)

        # 2. 계정 삭제 토큰 생성 및 Firestore에 저장
        # 보안을 위해 secrets 모듈을 사용하여 안전한 랜덤 토큰을 생성합니다.
        deletion_token = secrets.token_urlsafe(32) # 안전한 랜덤 토큰 (32바이트 길이)
        expires_at = datetime.now(timezone.utc) + timedelta(hours=1) # 토큰 만료 시간 (1시간 후)

        db.collection('account_deletion_tokens').doc(deletion_token).set({
            'uid': firebase_uid,
            'email': user_email,
            'created_at': datetime.now(timezone.utc),
            'expires_at': expires_at,
            'used': False # 토큰 사용 여부 플래그
        })

        # 3. 계정 삭제 확인 링크 생성
        # 이 링크는 사용자가 클릭할 웹 페이지(Firebase Hosting)로 연결됩니다.
        deletion_link = f"{APP_DOMAIN}/confirm-deletion?token={deletion_token}"

        # 4. Trigger Email Extension을 통해 이메일 발송 트리거
        # Trigger Email Extension 설치 시 설정한 'Collection path' (예: 'mail')에 문서를 추가합니다.
        try:
            db.collection('mail').add({ # <-- Extension 설치 시 설정한 컬렉션 이름과 일치해야 합니다!
                'to': user_email,
                'message': {
                    'subject': '서술형도 한다 앱 계정 삭제 확인 요청', # 이메일 제목 (앱 이름으로 변경)
                    'html': f'안녕하세요,<br><br>'
                            f'귀하의 계정 삭제 요청이 접수되었습니다. 계정 삭제를 계속하려면 다음 링크를 클릭해주세요:<br>'
                            f'<a href="{deletion_link}">계정 삭제 확인</a><br><br>'
                            f'이 링크는 1시간 후에 만료됩니다. 만약 본인이 요청한 것이 아니라면 이 이메일을 무시해주세요.<br><br>'
                            f'감사합니다.<br>'
                            f'---<br>'
                            f'이 이메일은 {APP_DOMAIN}에서 자동으로 발송되었습니다.'
                }
            })
            return https_fn.Response("계정 삭제 인증 메일이 요청되었습니다.", status=200)
        except Exception as e:
            print(f"Error adding document to mail collection: {e}")
            return https_fn.Response(f"Firestore를 통한 E메일 요청 에러: {e}", status=500)

    except Exception as e:
        print(f"Error in request_account_deletion function: {e}")
        return https_fn.Response(f"Internal Server Error: {e}", status=500)


# --- HTTP 트리거 함수: 계정 삭제 확인 처리 (이메일 링크 클릭 시) ---
@https_fn.on_request(cors_origins=["*"]) # CORS 허용 (개발 단계에서만 사용)
def confirm_account_deletion(request: https_fn.Request):
    """
    사용자가 이메일의 링크를 클릭했을 때 호출되어 계정 삭제를 최종적으로 처리합니다.
    """
    deletion_token = request.args.get('token') # URL 쿼리 파라미터에서 토큰 가져오기

    if not deletion_token:
        return https_fn.Response("삭제 토큰이 없습니다.", status=400)

    token_doc_ref = db.collection('account_deletion_tokens').document(deletion_token)
    token_doc = token_doc_ref.get()

    if not token_doc.exists:
        # 토큰이 없거나 이미 삭제된 경우 (예: 만료되거나 이미 사용됨)
        return https_fn.Response("<script>alert('유효하지 않거나 만료된 삭제 링크입니다. 새로운 요청을 해주세요.'); window.close();</script>", mimetype="text/html", status=400)

    token_data = token_doc.to_dict()

    if token_data.get('used'): # 이미 사용된 토큰인지 확인
        return https_fn.Response("<script>alert('이 삭제 링크는 이미 사용되었습니다.'); window.close();</script>", mimetype="text/html", status=400)

    expires_at = token_data.get('expires_at')
    # Firestore Timestamp 객체를 datetime 객체로 변환 (Functions 환경에서 Timestamp로 저장됨)
    if expires_at and expires_at.astimezone(timezone.utc) < datetime.now(timezone.utc):
        token_doc_ref.delete() # 만료된 토큰 Firestore에서 삭제
        return https_fn.Response("<script>alert('삭제 링크가 만료되었습니다. 새로운 요청을 해주세요.'); window.close();</script>", mimetype="text/html", status=400)

    user_uid_to_delete = token_data.get('uid')
    if not user_uid_to_delete:
        return https_fn.Response("<script>alert('사용자 ID를 찾을 수 없습니다.'); window.close();</script>", mimetype="text/html", status=500)

    try:
        # Firebase Auth에서 사용자 계정 삭제
        auth.delete_user(user_uid_to_delete)

        # Firestore에서 사용자 데이터 삭제 (users 컬렉션의 UID 문서)
        db.collection('users').document(user_uid_to_delete).delete()

        # 계정 삭제 토큰을 '사용됨'으로 표시 (또는 토큰 자체를 삭제)
        token_doc_ref.update({'used': True, 'used_at': datetime.now(timezone.utc)})

        # 계정 삭제 성공 메시지를 포함한 HTML 응답
        return https_fn.Response(f"<script>alert('계정이 성공적으로 삭제되었습니다. 앱으로 돌아가 다시 로그인하거나 회원가입 해주세요.'); window.close();</script>", mimetype="text/html", status=200)

    except Exception as e:
        print(f"Error deleting user account: {e}")
        # 오류 발생 시 사용자에게 보여줄 메시지
        return https_fn.Response(f"<script>alert('계정 삭제 중 오류가 발생했습니다: {e}'); window.close();</script>", mimetype="text/html", status=500)