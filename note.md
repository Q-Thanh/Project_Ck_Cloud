# 1. thêm các tính năng sau đây:
- Giữ ngón tay để kích hoạt hỏi AI phân tích xem đó là tờ tiền gì...
- ấn double tap để chuyển chế độ tiết kiệm pin
- ấn triple tap để bật đèn flask nếu trời tối
- Định vị xem user đang ở đâu(GPS) để tiện theo dõi  
# 2. Về database:
 - A. Hồ sơ người dùng (User Profile):
    + Gồm: Tên, Tuổi, Loại khiếm thị (mù hoàn toàn hay nhìn kém), Số điện thoại người thân (để gọi SOS).
    + Mục đích: Khi cài lại app hoặc đổi điện thoại, chỉ cần đăng nhập là mọi cài đặt (tốc độ giọng nói, chế độ rung...) tự động tải về. Không phải cài lại từ đầu.
 - B. Dữ liệu hành vi (Usage Logs - Ẩn danh):
    + Gồm: App hay dùng vào giờ nào? Tính năng nào dùng nhiều nhất (Đo khoảng cách hay Đọc chữ)?
    + Mục đích: Để bạn (Developer) biết tính năng nào quan trọng để nâng cấp. Ví dụ: Thấy ít ai dùng đèn Flash -> Phiên bản sau bỏ đi cho nhẹ.
 - C. Lịch sử quét & Lỗi sai (Detection History & Feedback):
    + Gồm: Danh sách vật thể đã quét. Quan trọng nhất là Nút "Báo sai". Ví dụ: AI nhìn "Con mèo" ra "Con chó", người dùng bấm báo lỗi.
    + Mục đích: Cực kỳ quan trọng để huấn luyện lại AI. Dữ liệu này giúp bạn làm cho AI thông minh hơn trong tương lai.
 - D. Logs Lỗi (Crash Logs):
    + Gồm: App bị văng (crash) lúc mấy giờ, trên dòng máy nào (Samsung hay Xiaomi).
    + Mục đích: Để bảo trì, sửa lỗi (Fix bug).
# 3. làm thêm trang admin(dashboard) để quản lý:
 - thống kê: xem có bn tài khoản sử dụng app hôm nay
 - ktra lỗi: Nếu có lỗi thì xem ở đâu để fix lại app
 - Quản lý: tài khoản user, phiên bản app để update app nếu có thay đổi
 - xem cái tkhoan spam thì ban
 - giao diện -> màu: trắng+blue 
 => các chức năg: thôgns kê; nhật ký hdong; 