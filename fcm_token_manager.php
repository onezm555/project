<?php
// fcm_token_manager.php - API สำหรับจัดการ FCM Token ของผู้ใช้
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS, PUT, DELETE');
header('Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With');

include 'conn.php';

$method = $_SERVER['REQUEST_METHOD'];

try {
    switch ($method) {
        case 'POST':
            // บันทึก/อัปเดต FCM Token
            $input = json_decode(file_get_contents('php://input'), true);
            
            $user_id = isset($input['user_id']) ? (int)$input['user_id'] : null;
            $fcm_token = isset($input['fcm_token']) ? trim($input['fcm_token']) : null;
            $device_id = isset($input['device_id']) ? trim($input['device_id']) : null;
            
            if (!$user_id || !$fcm_token) {
                echo json_encode([
                    'success' => false,
                    'message' => 'User ID and FCM Token are required'
                ]);
                exit();
            }
            
            // ตรวจสอบว่ามี Token นี้อยู่แล้วหรือไม่
            $check_sql = "SELECT id FROM user_fcm_tokens WHERE user_id = :user_id AND device_id = :device_id";
            $check_stmt = $conn->prepare($check_sql);
            $check_stmt->bindValue(':user_id', $user_id);
            $check_stmt->bindValue(':device_id', $device_id);
            $check_stmt->execute();
            
            if ($check_stmt->rowCount() > 0) {
                // อัปเดต Token ที่มีอยู่
                $update_sql = "UPDATE user_fcm_tokens SET fcm_token = :fcm_token, updated_at = NOW() WHERE user_id = :user_id AND device_id = :device_id";
                $update_stmt = $conn->prepare($update_sql);
                $update_stmt->bindValue(':fcm_token', $fcm_token);
                $update_stmt->bindValue(':user_id', $user_id);
                $update_stmt->bindValue(':device_id', $device_id);
                $update_stmt->execute();
                
                echo json_encode([
                    'success' => true,
                    'message' => 'FCM Token updated successfully'
                ]);
            } else {
                // เพิ่ม Token ใหม่
                $insert_sql = "INSERT INTO user_fcm_tokens (user_id, fcm_token, device_id, created_at, updated_at) VALUES (:user_id, :fcm_token, :device_id, NOW(), NOW())";
                $insert_stmt = $conn->prepare($insert_sql);
                $insert_stmt->bindValue(':user_id', $user_id);
                $insert_stmt->bindValue(':fcm_token', $fcm_token);
                $insert_stmt->bindValue(':device_id', $device_id);
                $insert_stmt->execute();
                
                echo json_encode([
                    'success' => true,
                    'message' => 'FCM Token saved successfully'
                ]);
            }
            break;
            
        case 'GET':
            // ดึง FCM Token ของผู้ใช้
            $user_id = isset($_GET['user_id']) ? (int)$_GET['user_id'] : null;
            
            if (!$user_id) {
                echo json_encode([
                    'success' => false,
                    'message' => 'User ID is required'
                ]);
                exit();
            }
            
            $select_sql = "SELECT fcm_token, device_id, created_at, updated_at FROM user_fcm_tokens WHERE user_id = :user_id AND fcm_token IS NOT NULL";
            $select_stmt = $conn->prepare($select_sql);
            $select_stmt->bindValue(':user_id', $user_id);
            $select_stmt->execute();
            $tokens = $select_stmt->fetchAll(PDO::FETCH_ASSOC);
            
            echo json_encode([
                'success' => true,
                'data' => $tokens
            ]);
            break;
            
        case 'DELETE':
            // ลบ FCM Token
            $input = json_decode(file_get_contents('php://input'), true);
            
            $user_id = isset($input['user_id']) ? (int)$input['user_id'] : null;
            $device_id = isset($input['device_id']) ? trim($input['device_id']) : null;
            
            if (!$user_id || !$device_id) {
                echo json_encode([
                    'success' => false,
                    'message' => 'User ID and Device ID are required'
                ]);
                exit();
            }
            
            $delete_sql = "DELETE FROM user_fcm_tokens WHERE user_id = :user_id AND device_id = :device_id";
            $delete_stmt = $conn->prepare($delete_sql);
            $delete_stmt->bindValue(':user_id', $user_id);
            $delete_stmt->bindValue(':device_id', $device_id);
            $delete_stmt->execute();
            
            echo json_encode([
                'success' => true,
                'message' => 'FCM Token deleted successfully'
            ]);
            break;
            
        default:
            echo json_encode([
                'success' => false,
                'message' => 'Method not allowed'
            ]);
            break;
    }
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Database error: ' . $e->getMessage()
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Unexpected error: ' . $e->getMessage()
    ]);
}
?>
