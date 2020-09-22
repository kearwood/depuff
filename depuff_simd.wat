(module
  (memory $mem 1152)
  (func $bc1_fast_compress_block (param $row0 v128)(param $row1 v128)(param $row2 v128)(param $row3 v128)(result i64)

;; Minimum palette entry, 32 bits per component
  (local $palette_min v128)

;; Maximum palette entry, 32 bits per component
  (local $palette_max v128)

  (local $palette_step v128)

;; Get maximum color
  get_local $row0
  get_local $row1
  i8x16.max_u
  get_local $row2
  i8x16.max_u
  get_local $row3
  i8x16.max_u
  tee_local $palette_max
  i16x8.widen_low_i8x16_u
  get_local $palette_max
  i16x8.widen_high_i8x16_u
  i16x8.max_u
  tee_local $palette_max
  i32x4.widen_low_i16x8_u
  get_local $palette_max
  i32x4.widen_high_i16x8_u
  i32x4.max_u
  set_local $palette_max

;; Get minimum color
  get_local $row0
  get_local $row1
  i8x16.min_u
  get_local $row2
  i8x16.min_u
  get_local $row3
  i8x16.min_u
  tee_local $palette_min
  i16x8.widen_low_i8x16_u
  get_local $palette_min
  i16x8.widen_high_i8x16_u
  i16x8.min_u
  tee_local $palette_min
  i32x4.widen_low_i16x8_u
  get_local $palette_min
  i32x4.widen_high_i16x8_u
  i32x4.min_u
  tee_local $palette_min

;; Check if any alpha values are less than 0x80

  ;; Extract the lowest alpha value

  i32x4.extract_lane 3
  i32.const 0x80
  i32.lt_u
  if
    ;; We have an alpha value of at least 0x80
    ;;
    ;; When there is alpha, our palette entries
    ;; consist of:
    ;; - Transparent
    ;; - palette_min
    ;; - palette_min * 1/2 + palette_max * 1/2
    ;; - palette_max
    ;;
    ;; When we have 3 non-transparent palette
    ;; entries, 1/4 of the total distance along
    ;; the color line is the half-way point between
    ;; the first and second palette entry
    get_local $palette_max
    get_local $palette_min
    i32x4.sub
    tee_local $palette_step
    get_local $palette_step
    i32x4.mul
    ;; We store $palette_step in fixed point notation
    ;; with the decimal at 0x100
    i32.const 0x40 ;; 0x100 / 4
    i32x4.splat
    i32x4.mul
    set_local $palette_step

    ;; We perform a dot product to determine the position of each pixel
    ;; color along a color line connecting palette_min and palette_max.
    ;; Below 1/4 along the color line, the 1st palette entry is selected.
    ;; At 1/4 along the color line, the 2nd palette entry is selected.
    ;; At 3/4 along the color line, the 3rd palette entry is selected.
  else
    ;; No alpha values less than 0x80
    ;;
    ;; When there is no alpha, our palette entries
    ;; consist of:
    ;; - palette_min
    ;; - palette_min * 2/3 + palette_max * 1/3
    ;; - palette_min * 1/3 + palette_max * 2/3
    ;; - palette_max
    ;;
    ;; When we have 4 non-transparent palette
    ;; entries, 1/6 of the total distance along
    ;; the color line is the half-way point between
    ;; the first and second palette entry
    get_local $palette_max
    get_local $palette_min
    i32x4.sub
    tee_local $palette_step
    get_local $palette_step
    i32x4.mul
    ;; We store $palette_step in fixed point notation
    ;; with the decimal at 0x100
    i32.const 0x2a ;; 0x100 / 6
    i32x4.splat
    i32x4.mul
    set_local $palette_step

    ;; We perform a dot product to determine the position of each pixel
    ;; color along a color line connecting palette_min and palette_max.
    ;; Below 1/6 along the color line, the 1st palette entry is selected.
    ;; At 1/6 along the color line, the 2nd palette entry is selected.
    ;; At 3/6 along the color line, the 3rd palette entry is selected.
    ;; At 5/6 along the color line, the 4th palette entry is selected.
  end

;;   (local $min_color i32)
;;   (local $max_color i32)
;;   (local $pixel_index i32)
;;   
;;   i32.const 0
;;   set_local $max_color
;;   i32.const 0xffffffff
;;   set_local $min_color
;;
;;    i32.const 0
;;    set_local $pixel_index
;;
;;    loop
;;
;;      get_local $max_color
;;      i32.const 100100
;;      i32.add
;;      set_local $max_color
;;
;;      get_local $pixel_index
;;      i32.const 1
;;      i32.add
;;      tee_local $pixel_index
;;
;;      i32.const 16
;;      i32.lt_u
;;      br_if 0
;;
;;    end

    i64.const 0
  )

  (func $bc1_fast_rgba (param $width i32)(param $height i32)(param $thread_id i32)(param $thread_count i32)(result i64)
    (local $pixel_address i32)
    (local $row_address i32)
    i32.const 0
    set_local $pixel_address

    ;; Load Row 0 of Block
    get_local $pixel_address
    tee_local $row_address
    v128.load

    ;; Load Row 1 of Block
    get_local $row_address
    get_local $width
    i32.add
    tee_local $row_address
    v128.load

    ;; Load Row 2 of Block
    get_local $row_address
    get_local $width
    i32.add
    tee_local $row_address
    v128.load

    ;; Load Row 3 of Block
    get_local $row_address
    get_local $width
    i32.add
    tee_local $row_address
    v128.load

    call $bc1_fast_compress_block

    ;; Advance to next block
    get_local $pixel_address
    i32.const 4
    i32.add
    set_local $pixel_address
  )

  (export "bc1_fast_rgba" (func $bc1_fast_rgba))
  (export "memory" (memory $mem))
)
