<?php
// admin_manage_types.php - หลังบ้านสำหรับจัดการประเภทสินค้าและรูป default
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE');
header('Access-Control-Allow-Headers: Content-Type');

include 'conn.php';

$method = $_SERVER['REQUEST_METHOD'];

switch ($method) {
    case 'GET':
        // ดึงข้อมูลประเภทสินค้าทั้งหมด
        try {
            $stmt = $pdo->prepare("SELECT type_id, type_name, default_image FROM types ORDER BY type_id");
            $stmt->execute();
            $types = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            echo json_encode([
                'status' => 'success',
                'data' => $types
            ]);
        } catch (PDOException $e) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Database error: ' . $e->getMessage()
            ]);
        }
        break;
        
    case 'POST':
        // เพิ่มประเภทใหม่
        $input = json_decode(file_get_contents('php://input'), true);
        $type_name = $input['type_name'] ?? '';
        $default_image = $input['default_image'] ?? 'default.png';
        
        if (empty($type_name)) {
            echo json_encode(['status' => 'error', 'message' => 'Type name is required']);
            exit;
        }
        
        try {
            // ตรวจสอบว่าชื่อประเภทซ้ำหรือไม่
            $stmt_check = $pdo->prepare("SELECT COUNT(*) FROM types WHERE type_name = ?");
            $stmt_check->execute([$type_name]);
            if ($stmt_check->fetchColumn() > 0) {
                echo json_encode(['status' => 'error', 'message' => 'Type name already exists']);
                exit;
            }
            
            $stmt = $pdo->prepare("INSERT INTO types (type_name, default_image) VALUES (?, ?)");
            $stmt->execute([$type_name, $default_image]);
            
            echo json_encode([
                'status' => 'success',
                'message' => 'Type added successfully',
                'type_id' => $pdo->lastInsertId()
            ]);
        } catch (PDOException $e) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Database error: ' . $e->getMessage()
            ]);
        }
        break;
        
    case 'PUT':
        // แก้ไขประเภทสินค้า
        $input = json_decode(file_get_contents('php://input'), true);
        $type_id = $input['type_id'] ?? 0;
        $type_name = $input['type_name'] ?? '';
        $default_image = $input['default_image'] ?? '';
        
        if (empty($type_id) || empty($type_name)) {
            echo json_encode(['status' => 'error', 'message' => 'Type ID and name are required']);
            exit;
        }
        
        try {
            // ตรวจสอบว่าชื่อประเภทซ้ำหรือไม่ (ยกเว้น record ปัจจุบัน)
            $stmt_check = $pdo->prepare("SELECT COUNT(*) FROM types WHERE type_name = ? AND type_id != ?");
            $stmt_check->execute([$type_name, $type_id]);
            if ($stmt_check->fetchColumn() > 0) {
                echo json_encode(['status' => 'error', 'message' => 'Type name already exists']);
                exit;
            }
            
            $stmt = $pdo->prepare("UPDATE types SET type_name = ?, default_image = ? WHERE type_id = ?");
            $stmt->execute([$type_name, $default_image, $type_id]);
            
            echo json_encode([
                'status' => 'success',
                'message' => 'Type updated successfully'
            ]);
        } catch (PDOException $e) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Database error: ' . $e->getMessage()
            ]);
        }
        break;
        
    case 'DELETE':
        // ลบประเภทสินค้า
        $input = json_decode(file_get_contents('php://input'), true);
        $type_id = $input['type_id'] ?? 0;
        
        if (empty($type_id)) {
            echo json_encode(['status' => 'error', 'message' => 'Type ID is required']);
            exit;
        }
        
        try {
            // ตรวจสอบว่ามีสินค้าใช้ประเภทนี้อยู่หรือไม่
            $stmt_check = $pdo->prepare("SELECT COUNT(*) FROM items WHERE type_id = ?");
            $stmt_check->execute([$type_id]);
            if ($stmt_check->fetchColumn() > 0) {
                echo json_encode(['status' => 'error', 'message' => 'Cannot delete type that is being used by items']);
                exit;
            }
            
            $stmt = $pdo->prepare("DELETE FROM types WHERE type_id = ?");
            $stmt->execute([$type_id]);
            
            echo json_encode([
                'status' => 'success',
                'message' => 'Type deleted successfully'
            ]);
        } catch (PDOException $e) {
            echo json_encode([
                'status' => 'error',
                'message' => 'Database error: ' . $e->getMessage()
            ]);
        }
        break;
        
    default:
        http_response_code(405);
        echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
        break;
}
?>
