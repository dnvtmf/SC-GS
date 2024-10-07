#!/usr/bin/env bash
#!/usr/bin/env bash
scenes=(as  basin  bell  cup  plate  press  sieve)
gpus=(0 1 2 3 4 5 6 7)
args=()
test_args=()
num_scenes=${#scenes[@]}
num_gpus=${#gpus[@]}
echo "There are ${num_gpus} gpus and ${num_scenes} scenes"

for (( i = 0;  i < ${num_gpus}; ++i ))
do
    gpu_id="gpu${gpus[$i]}"
    if ! screen -ls ${gpu_id}
    then
        echo "create ${gpu_id}"
        screen -dmS ${gpu_id}
    fi
    screen -S ${gpu_id} -p 0 -X stuff "^M"
    screen -S ${gpu_id} -p 0 -X stuff "export CUDA_VISIBLE_DEVICES=${gpus[$i]}^M"
    screen -S ${gpu_id} -p 0 -X stuff "cd ~/Projects/NeRF/SC-GS^M"
done
screen -ls%
#--deform_type node --node_num 4096 --deform_lr_scale 1 --eval --resolution 1 --gt_alpha_mask_as_dynamic_mask --node_warm_up 500 --iterations_node_sampling 7500 --iterations_node_rendering 10000 --oneupSHdegree_step 5000 --warm_up 3000 --hyper_dim 8 --local_frame --pred_color --pred_opacity --dynamic_color_warm_up 20000 --deform_downsamp_strategy direct
for (( i=0; i < num_scenes; ++i ))
do
    gpu_id=${gpus[$(( i % num_gpus ))]}
    echo "use gpu${gpu_id} on scene: ${scenes[i]} "
    screen -S gpu${gpu_id} -p 0 -X stuff "^M"
    screen -S gpu${gpu_id} -p 0 -X stuff \
      "python3 train_gui.py \
        --source_path ~/data/NeRF/NeRF_DS/${scenes[i]} --model_path outputs/NeRF_DS/${scenes[i]} \
        --deform_type node --node_num 512 --is_blender --eval \
        --gt_alpha_mask_as_scene_mask --local_frame \
        --W 480 --H 270 \
        ${args[*]} ^M"
    if [[ ! -e outputs/NeRF_DS/${scenes[i]}_node/test ]]
    then
      screen -S gpu${gpu_id} -p 0 -X stuff \
        "python3 render.py \
          --source_path ~/data/NeRF/NeRF_DS/${scenes[i]} --model_path outputs/NeRF_DS/${scenes[i]} \
          --deform_type node --node_num 512 --is_blender --eval \
          --gt_alpha_mask_as_scene_mask --local_frame \
          --W 480 --H 270 --skip_train \
          ${args[*]} ${test_args[*]} ^M"
    fi
    if [[ ! -e  outputs/NeRF_DS/${scenes[i]}_node/results.json ]]
    then
      screen -S gpu${gpu_id} -p 0 -X stuff \
        "python3 metrics.py --model_path outputs/NeRF_DS/${scenes[i]}_node ^M"
    fi
done
