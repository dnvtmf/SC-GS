#!/usr/bin/env bash
scenes=(hellwarrior hook jumpingjacks mutant  standup trex lego)
gpus=(0 1 2 3 4 5 6 7 8 9)
num_control_points=(128 256 384 512)
args=()
out_dir=DNeRF_ab
test_args=()
num_scenes=${#scenes[@]}
num_gpus=${#gpus[@]}
echo "There are ${num_gpus} gpus and ${num_scenes} scenes ${#num_control_points[@]} cases"

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

k=0
for (( i=0; i < num_scenes; ++i ))
do
    for num_cp in ${num_control_points[@]}
    do
        gpu_id=${gpus[$(( k % num_gpus ))]}
        k=$(( k + 1 ))
        echo "use gpu${gpu_id} on scene: ${scenes[i]}, num_cp=${num_cp}"
        screen -S gpu${gpu_id} -p 0 -X stuff "^M"
        screen -S gpu${gpu_id} -p 0 -X stuff "python3 train_gui.py \
            --source_path ~/data/NeRF/D_NeRF/${scenes[i]} \
            --model_path outputs/${out_dir}/${scenes[i]}/${num_cp} \
            --deform_type node --node_num ${num_cp}  --hyper_dim 8 --is_blender --eval \
            --gt_alpha_mask_as_scene_mask --local_frame \
            --resolution 2 --W 800 --H 800 \
            ${args[*]} ^M"
        screen -S gpu${gpu_id} -p 0 -X stuff "python3 render.py \
            --source_path ~/data/NeRF/D_NeRF/${scenes[i]} \
            --model_path outputs/${out_dir}/${scenes[i]}/${num_cp} \
            --deform_type node --node_num ${num_cp} --hyper_dim 8 --is_blender --eval \
            --gt_alpha_mask_as_scene_mask --local_frame \
            --resolution 2 --W 800 --H 800 \
            ${args[*]} ${test_args[*]} ^M"

        screen -S gpu${gpu_id} -p 0 -X stuff \
          "python3 metrics.py -m outputs/${out_dir}/${scenes[i]}/${num_cp}_node ^M"
    done
done
