<?php
// notification_check.php - API สำหรับตรวจสอบและส่งการแจ้งเตือนสินค้าใกล้หมดอายุ
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With');

include 'conn.php';

$current_user_id = isset($_GET['user_id']) ? (int)$_GET['user_id'] : null;
$check_only = isset($_GET['check_only']) ? filter_var($_GET['check_only'], FILTER_VALIDATE_BOOLEAN) : false;

if ($current_user_id === null) {
    echo json_encode([
        "success" => false,
        "message" => "User ID is required."
    ]);
    exit();
}

try {
    // Query สำหรับดึงสินค้าที่ยังใช้งานได้ (active) และตรวจสอบวันหมดอายุ
    $sql = "
        SELECT
            i.item_id,
            i.user_id,
            i.item_name,
            i.item_number,
            i.item_img,
            i.item_date,
            i.item_notification,
            i.item_barcode,
            i.item_status,
            i.date_type,
            t.type_name,
            a.area_name,
            DATEDIFF(i.item_date, CURDATE()) as days_left,
            DATE_SUB(i.item_date, INTERVAL i.item_notification DAY) as notify_date
        FROM
            items i
        LEFT JOIN types t ON i.type_id = t.type_id
        LEFT JOIN areas a ON i.area_id = a.area_id
        WHERE 
            i.user_id = :user_id 
            AND i.item_status = 'active'
            AND i.item_notification > 0
        ORDER BY i.item_date ASC
    ";

    $stmt = $conn->prepare($sql);
    $stmt->bindValue(':user_id', $current_user_id);
    $stmt->execute();
    $items = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $notifications = [];
    $current_date = new DateTime();

    foreach ($items as $item) {
        $expire_date = new DateTime($item['item_date']);
        $notify_date = new DateTime($item['notify_date']);
        $days_left = (int)$item['days_left'];
        
        // ตรวจสอบว่าถึงเวลาแจ้งเตือนแล้วหรือยัง
        $should_notify = $current_date >= $notify_date && $current_date <= $expire_date->modify('+1 day');
        
        if ($should_notify) {
            $item_img_full_url = get_full_image_url($item['item_img']);
            if (empty($item_img_full_url)) {
                $item_img_full_url = 'assets/images/default.png';
            }

            $notification_data = [
                'item_id' => $item['item_id'],
                'user_id' => $item['user_id'],
                'item_name' => $item['item_name'],
                'item_number' => $item['item_number'],
                'item_img_full_url' => $item_img_full_url,
                'item_date' => $item['item_date'],
                'item_notification' => $item['item_notification'],
                'item_barcode' => $item['item_barcode'],
                'item_status' => $item['item_status'],
                'date_type' => $item['date_type'],
                'category' => $item['type_name'],
                'storage_location' => $item['area_name'],
                'days_left' => $days_left,
                'notify_date' => $item['notify_date'],
                'notification_type' => $days_left <= 0 ? 'expired' : 'expiring',
                'notification_title' => 'สินค้าใกล้หมดอายุ',
                'notification_message' => $days_left < 0 
                    ? $item['item_name'] . ' หมดอายุแล้ว'
                    : $item['item_name'] . ' จะหมดอายุในอีก ' . $days_left . ' วัน',
                'created_at' => $current_date->format('Y-m-d H:i:s')
            ];

            $notifications[] = $notification_data;

            // ถ้าไม่ใช่แค่ check_only ให้ส่งการแจ้งเตือนจริง
            if (!$check_only) {
                // TODO: เพิ่ม FCM notification ตรงนี้
                // sendFCMNotification($user_fcm_token, $notification_data);
            }
        }
    }

    // สถิติการแจ้งเตือน
    $expired_count = count(array_filter($notifications, function($n) {
        return $n['notification_type'] === 'expired';
    }));
    
    $expiring_count = count(array_filter($notifications, function($n) {
        return $n['notification_type'] === 'expiring';
    }));

    echo json_encode([
        "success" => true,
        "data" => $notifications,
        "summary" => [
            "total_notifications" => count($notifications),
            "expired_items" => $expired_count,
            "expiring_items" => $expiring_count
        ],
        "check_time" => $current_date->format('Y-m-d H:i:s')
    ]);

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

// ฟังก์ชันส่ง FCM Notification (สำหรับอนาคต)
function sendFCMNotification($fcm_token, $notification_data) {
    // TODO: เพิ่ม Firebase Cloud Messaging ตรงนี้
    // $serverKey = 'YOUR_FIREBASE_SERVER_KEY';
    // 
    // $url = 'https://fcm.googleapis.com/fcm/send';
    // 
    // $notification = [
    //     'title' => $notification_data['notification_title'],
    //     'body' => $notification_data['notification_message'],
    //     'sound' => 'default'
    // ];
    // 
    // $fields = [
    //     'to' => $fcm_token,
    //     'notification' => $notification,
    //     'data' => [
    //         'item_id' => $notification_data['item_id'],
    //         'type' => $notification_data['notification_type']
    //     ]
    // ];
    // 
    // $headers = [
    //     'Authorization: key=' . $serverKey,
    //     'Content-Type: application/json'
    // ];
    // 
    // $ch = curl_init();
    // curl_setopt($ch, CURLOPT_URL, $url);
    // curl_setopt($ch, CURLOPT_POST, true);
    // curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    // curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    // curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($fields));
    // 
    // $result = curl_exec($ch);
    // curl_close($ch);
    // 
    // return json_decode($result, true);
    
    return ['success' => true, 'message' => 'FCM not implemented yet'];
}
?>
