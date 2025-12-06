"""
RomaSub.AI Demo UI

Simple Streamlit interface for testing the backend API.
This is a temporary demo UI - will be replaced with Flutter frontend.

Run with: streamlit run demo/demo_ui.py
"""

import streamlit as st
import requests
import json
from datetime import datetime

# API Base URL
API_URL = "http://localhost:8000"

# Page configuration
st.set_page_config(
    page_title="RomaSub.AI Demo",
    page_icon="🎬",
    layout="wide"
)

# Custom CSS
st.markdown("""
<style>
    .main-header {
        font-size: 2.5rem;
        color: #1a73e8;
        text-align: center;
        margin-bottom: 1rem;
    }
    .sub-header {
        font-size: 1.2rem;
        color: #666;
        text-align: center;
        margin-bottom: 2rem;
    }
    .success-box {
        background-color: #d4edda;
        padding: 1rem;
        border-radius: 0.5rem;
        border: 1px solid #c3e6cb;
    }
    .error-box {
        background-color: #f8d7da;
        padding: 1rem;
        border-radius: 0.5rem;
        border: 1px solid #f5c6cb;
    }
</style>
""", unsafe_allow_html=True)

# Initialize session state
if 'token' not in st.session_state:
    st.session_state.token = None
if 'user' not in st.session_state:
    st.session_state.user = None
if 'file_id' not in st.session_state:
    st.session_state.file_id = None


def api_request(method, endpoint, data=None, files=None, auth=False):
    """Make API request"""
    url = f"{API_URL}{endpoint}"
    headers = {}
    
    if auth and st.session_state.token:
        headers["Authorization"] = f"Bearer {st.session_state.token}"
    
    try:
        if method == "GET":
            response = requests.get(url, headers=headers)
        elif method == "POST":
            if files:
                response = requests.post(url, files=files, headers=headers)
            else:
                headers["Content-Type"] = "application/json"
                response = requests.post(url, json=data, headers=headers)
        elif method == "DELETE":
            response = requests.delete(url, headers=headers)
        
        return response.json(), response.status_code
    except requests.exceptions.ConnectionError:
        return {"error": "Cannot connect to API. Make sure the server is running."}, 500
    except Exception as e:
        return {"error": str(e)}, 500


# Header
st.markdown('<h1 class="main-header">🎬 RomaSub.AI Demo</h1>', unsafe_allow_html=True)
st.markdown('<p class="sub-header">Roman Urdu Captions Generator - API Testing Interface</p>', unsafe_allow_html=True)

# Sidebar - Authentication
with st.sidebar:
    st.header("👤 Authentication")
    
    if st.session_state.token:
        st.success(f"Logged in as: {st.session_state.user['email']}")
        if st.button("Logout"):
            st.session_state.token = None
            st.session_state.user = None
            st.rerun()
    else:
        auth_tab = st.radio("Select", ["Login", "Register", "Forgot Password"])
        
        if auth_tab == "Login":
            st.subheader("Login")
            email = st.text_input("Email", key="login_email")
            password = st.text_input("Password", type="password", key="login_password")
            
            if st.button("Login"):
                result, status = api_request("POST", "/auth/login/json", {
                    "email": email,
                    "password": password
                })
                
                if status == 200:
                    st.session_state.token = result["access_token"]
                    st.session_state.user = result["user"]
                    st.success("Login successful!")
                    st.rerun()
                else:
                    st.error(result.get("detail", "Login failed"))
        
        elif auth_tab == "Register":
            st.subheader("Register")
            first_name = st.text_input("First Name")
            last_name = st.text_input("Last Name")
            email = st.text_input("Email", key="reg_email")
            password = st.text_input("Password", type="password", key="reg_password")
            confirm_password = st.text_input("Confirm Password", type="password")
            
            if st.button("Register"):
                result, status = api_request("POST", "/auth/register", {
                    "first_name": first_name,
                    "last_name": last_name,
                    "email": email,
                    "password": password,
                    "confirm_password": confirm_password
                })
                
                if status == 201:
                    st.session_state.token = result["access_token"]
                    st.session_state.user = result["user"]
                    st.success("Registration successful!")
                    st.rerun()
                else:
                    st.error(result.get("detail", "Registration failed"))
        
        else:  # Forgot Password
            st.subheader("Forgot Password")
            email = st.text_input("Email", key="forgot_email")
            
            if st.button("Send OTP"):
                result, status = api_request("POST", "/auth/forgot-password", {
                    "email": email
                })
                st.info(result.get("message", "Check your email for OTP"))
            
            st.divider()
            st.subheader("Reset Password")
            reset_email = st.text_input("Email", key="reset_email")
            otp = st.text_input("OTP Code")
            new_password = st.text_input("New Password", type="password")
            confirm_new = st.text_input("Confirm New Password", type="password")
            
            if st.button("Reset Password"):
                result, status = api_request("POST", "/auth/reset-password", {
                    "email": reset_email,
                    "otp": otp,
                    "new_password": new_password,
                    "confirm_password": confirm_new
                })
                
                if status == 200:
                    st.success("Password reset successful! Please login.")
                else:
                    st.error(result.get("detail", "Reset failed"))

# Main content - Tabs
tab1, tab2, tab3 = st.tabs(["📤 Upload Media", "🎤 Transcribe", "📊 Results"])

with tab1:
    st.header("Module 2: Upload Video/Audio")
    
    st.info("""
    **Supported formats:**
    - Video: MP4, AVI, MKV, MOV, WEBM
    - Audio: MP3, WAV, M4A, FLAC, OGG
    
    **Max file size:** 500MB
    """)
    
    uploaded_file = st.file_uploader(
        "Choose a video or audio file",
        type=["mp4", "avi", "mkv", "mov", "webm", "mp3", "wav", "m4a", "flac", "ogg"]
    )
    
    if uploaded_file:
        st.write(f"**File:** {uploaded_file.name}")
        st.write(f"**Size:** {uploaded_file.size / (1024*1024):.2f} MB")
        
        if st.button("Upload File"):
            with st.spinner("Uploading..."):
                files = {"file": (uploaded_file.name, uploaded_file, uploaded_file.type)}
                result, status = api_request("POST", "/media/upload/anonymous", files=files)
                
                if status == 200:
                    st.session_state.file_id = result["file_id"]
                    st.success(f"✅ Upload successful!")
                    st.json(result)
                else:
                    st.error(result.get("detail", "Upload failed"))
    
    st.divider()
    
    # Show current file info
    if st.session_state.file_id:
        st.subheader("Current File")
        result, status = api_request("GET", f"/media/{st.session_state.file_id}")
        
        if status == 200:
            col1, col2 = st.columns(2)
            with col1:
                st.write(f"**File ID:** `{result['file_id']}`")
                st.write(f"**Filename:** {result['original_filename']}")
            with col2:
                st.write(f"**Status:** {result['status']}")
                st.write(f"**Type:** {'Video' if result['is_video'] else 'Audio'}")

with tab2:
    st.header("Module 3: Speech Recognition (ASR)")
    
    if not st.session_state.file_id:
        st.warning("Please upload a file first in the Upload tab.")
    else:
        st.write(f"**Current File ID:** `{st.session_state.file_id}`")
        
        language = st.selectbox(
            "Select Language",
            options=["ur", "en", "hi", "ar"],
            format_func=lambda x: {"ur": "Urdu", "en": "English", "hi": "Hindi", "ar": "Arabic"}[x],
            index=0
        )
        
        st.warning("⚠️ First transcription will take longer as Whisper model needs to be loaded.")
        
        if st.button("🎤 Start Transcription"):
            with st.spinner("Transcribing... This may take a while depending on file length."):
                result, status = api_request(
                    "POST", 
                    f"/asr/transcribe/{st.session_state.file_id}/anonymous",
                    data={"language": language}
                )
                
                if status == 200:
                    st.success("✅ Transcription Complete!")
                    
                    # Show stats
                    col1, col2, col3 = st.columns(3)
                    with col1:
                        st.metric("Segments", result["segment_count"])
                    with col2:
                        st.metric("Processing Time", f"{result['processing_time_seconds']:.1f}s")
                    with col3:
                        if result.get("audio_duration_seconds"):
                            st.metric("Audio Duration", f"{result['audio_duration_seconds']:.1f}s")
                    
                    # Show full text
                    st.subheader("Full Transcription")
                    st.text_area("Transcribed Text", result["text"], height=200)
                    
                    # Show segments
                    st.subheader("Segments with Timestamps")
                    for seg in result["segments"][:20]:  # Show first 20
                        st.write(f"**[{seg['start']:.2f}s - {seg['end']:.2f}s]** {seg['text']}")
                    
                    if len(result["segments"]) > 20:
                        st.info(f"... and {len(result['segments']) - 20} more segments")
                else:
                    st.error(result.get("detail", "Transcription failed"))

with tab3:
    st.header("Results & Export")
    
    file_id_input = st.text_input(
        "File ID", 
        value=st.session_state.file_id if st.session_state.file_id else "",
        placeholder="Enter file ID to view results"
    )
    
    if file_id_input:
        if st.button("Get Results"):
            result, status = api_request("GET", f"/asr/result/{file_id_input}")
            
            if status == 200:
                st.success("Results found!")
                
                # Display results
                st.subheader("Transcription")
                st.text_area("Text", result["text"], height=150)
                
                # Get SRT
                srt_result, srt_status = api_request("GET", f"/asr/result/{file_id_input}/srt")
                
                if srt_status == 200:
                    st.subheader("SRT Format")
                    st.text_area("SRT Content", srt_result["srt_content"], height=200)
                    
                    # Download button
                    st.download_button(
                        label="📥 Download SRT",
                        data=srt_result["srt_content"],
                        file_name=f"{file_id_input}.srt",
                        mime="text/plain"
                    )
            else:
                st.error(result.get("detail", "No results found"))

# Footer
st.divider()
st.markdown("""
<div style="text-align: center; color: #666; font-size: 0.9rem;">
    <p><strong>RomaSub.AI</strong> - Roman Urdu Captions Generator</p>
    <p>COMSATS University Islamabad, Abbottabad Campus</p>
    <p>Final Year Project 2024-2025</p>
</div>
""", unsafe_allow_html=True)
