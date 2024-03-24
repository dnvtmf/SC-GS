#!/usr/bin/env bash
scenes=(hellwarrior  hook  jumpingjacks mutant  standup trex lego)
gpus=(1 2 3 4 5 6 8 9)
#args=(--resolution 2)
#out_dir=DNeRF_400
args=()
out_dir=DNeRF
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

for (( i=0; i < num_scenes; ++i ))
do
    gpu_id=${gpus[$(( i % num_gpus ))]}
    echo "use gpu${gpu_id} on scene: ${scenes[i]} "
    screen -S gpu${gpu_id} -p 0 -X stuff "^M"
    if [[ ! -e "outputs/${out_dir}/${scenes[i]}_node/deform/iteration_80000" ]]
    then
      screen -S gpu${gpu_id} -p 0 -X stuff \
        "python3 train_gui.py \
          --source_path ~/data/NeRF/D_NeRF/${scenes[i]} --model_path outputs/${out_dir}/${scenes[i]} \
          --deform_type node --node_num 512 --is_blender --eval \
          --gt_alpha_mask_as_scene_mask --local_frame \
          --W 800 --H 800 \
          ${args[*]} ^M"
    fi

    if [[ ! -e "outputs/${out_dir}/${scenes[i]}_node/test/ours_80000" ]]
    then
      screen -S gpu${gpu_id} -p 0 -X stuff \
        "python3 render.py \
          --source_path ~/data/NeRF/D_NeRF/${scenes[i]} --model_path outputs/${out_dir}/${scenes[i]} \
          --deform_type node --node_num 512 --is_blender --eval \
          --gt_alpha_mask_as_scene_mask --local_frame \
          --W 800 --H 800 --iteration 80000 \
          ${args[*]} ${test_args[*]} ^M"
    fi
    screen -S gpu${gpu_id} -p 0 -X stuff \
      "python3 metrics.py -m outputs/${out_dir}/${scenes[i]}_node ^M"
done
