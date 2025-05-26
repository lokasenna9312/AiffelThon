# functions/main.py (최종본, service_account 인수를 데코레이터에서 제거)

import firebase_admin
from firebase_admin import credentials, auth, firestore
from firebase_functions import https_fn # options 모듈 임포트 제거
import os
import secrets
from datetime import datetime, timedelta, timezone

# --- Firebase Admin SDK 초기화 ---
# Firebase Functions 환경에서는 자동으로 초기화됩니다.
# (만약 이미 초기화되었다면 ValueError 발생하므로 try-except로 처리)
if not firebase_admin._apps:
    try:
        firebase_admin.initialize_app()
    except ValueError:
        pass

# --- 환경 변수 설정 ---
APP_DOMAIN = os.environ.get("APP_DOMAIN", "https://certificatestudyaiffelcore12th.web.app")
SENDER_EMAIL = os.environ.get("SENDER_EMAIL", "no-reply@certificatestudyaiffelcore12th.web.app")

# CUSTOM_SERVICE_ACCOUNT_EMAIL 변수는 이제 main.py 내부에서 사용되지 않습니다.
# 대신 firebase.json에서 설정할 것입니다.


# --- HTTP 트리거 함수: 계정 삭제 요청 처리 ---
@https_fn.on_request(region="asia-northeast3") # <-- service_account 관련 인수 모두 제거!
def request_account_deletion(request: https_fn.Request):
    """
    클라이언트로부터 계정 삭제 요청을 받아, 확인 이메일 발송을 트리거합니다.
    이메일은 Trigger Email Extension을 통해 발송됩니다.
    """
    db_instance = firestore.client()

    if request.method != 'POST':
        return https_fn.Response("POST requests만 허용됩니다.", status=405)

    try:
        request_json = request.get_json()
        user_id = request_json.get('id')
        user_email = request_json.get('email')

        if not user_id or not user_email:
            return https_fn.Response("'id' 또는 'email'이 누락되어 있습니다.", status=400)

        user_docs_list = db_instance.collection('users').where('id', '==', user_id).limit(1).get()

        if not user_docs_list:
            return https_fn.Response("그런 ID를 쓰는 회원은 없습니다.", status=404)

        found_user_data = user_docs_list[0].to_dict()
        stored_email = found_user_data.get('email')
        firebase_uid = user_docs_list[0].id

        if stored_email != user_email:
            return https_fn.Response("입력하신 E메일은 이 ID에 등록된 E메일이 아닙니다.", status=400)

        deletion_token = secrets.token_urlsafe(32)

        expires_at = datetime.now(timezone.utc) + timedelta(hours=1)
        db_instance.collection('account_deletion_tokens').doc(deletion_token).set({
            'uid': firebase_uid,
            'email': user_email,
            'created_at': datetime.now(timezone.utc),
            'expires_at': expires_at,
            'used': False
        })

        deletion_link = f"{APP_DOMAIN}/confirm-deletion?token={deletion_token}"

        try:
            db_instance.collection('mail').add({
                'to': user_email,
                'message': {
                    'subject': '서술형도 한다 앱 계정 삭제 확인 요청',
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
@https_fn.on_request(region="asia-northeast3") # <-- service_account 관련 인수 모두 제거!
def confirm_account_deletion(request: https_fn.Request):
    """
    사용자가 이메일의 링크를 클릭했을 때 호출되어 계정 삭제를 최종적으로 처리합니다.
    """
    db_instance = firestore.client()

    deletion_token = request.args.get('token')

    if not deletion_token:
        return https_fn.Response("삭제 토큰이 없습니다.", status=400)

    token_doc_ref = db_instance.collection('account_deletion_tokens').document(deletion_token)
    token_doc = token_doc_ref.get()

    if not token_doc.exists:
        return https_fn.Response("<script>alert('유효하지 않거나 만료된 삭제 링크입니다. 새로운 요청을 해주세요.'); window.close();</script>", mimetype="text/html", status=400)

    token_data = token_doc.to_dict()

    if token_data.get('used'):
        return https_fn.Response("<script>alert('이 삭제 링크는 이미 사용되었습니다.'); window.close();</script>", mimetype="text/html", status=400)

    expires_at = token_data.get('expires_at')
    if expires_at and expires_at.astimezone(timezone.utc) < datetime.now(timezone.utc):
        token_doc_ref.delete()
        return https_fn.Response("<script>alert('삭제 링크가 만료되었습니다. 새로운 요청을 해주세요.'); window.close();</script>", mimetype="text/html", status=400)

    user_uid_to_delete = token_data.get('uid')
    if not user_uid_to_delete:
        return https_fn.Response("<script>alert('사용자 ID를 찾을 수 없습니다.'); window.close();</script>", mimetype="text/html", status=500)

    try:
        auth.delete_user(user_uid_to_delete)

        db_instance.collection('users').document(user_uid_to_delete).delete()

        token_doc_ref.update({'used': True, 'used_at': datetime.now(timezone.utc)})

        return https_fn.Response(f"<script>alert('계정이 성공적으로 삭제되었습니다. 앱으로 돌아가 다시 로그인하거나 회원가입 해주세요.'); window.close();</script>", mimetype="text/html", status=200)

    except Exception as e:
        print(f"Error deleting user account: {e}")
        return https_fn.Response(f"계정 삭제 중 오류가 발생했습니다: {e}", status=500)